import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

class NearbyTransitList extends StatefulWidget {
  final double latitude;
  final double longitude;
  final ScrollController scrollController;

  const NearbyTransitList({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.scrollController,
  });

  static const String query = r'''
    query GetNearbyDepartures($lat: Float!, $lon: Float!) {
      nearest(lat: $lat, lon: $lon, filterByPlaceTypes: DEPARTURE_ROW) {
        edges {
          node {
            id
            distance
            place {
              id
              __typename
              lat
              lon
              ... on DepartureRow {
                pattern {
                  headsign
                  route {
                    shortName
                    longName
                  }
                }
                stoptimes(timeRange: 7200) {
                  scheduledDeparture
                }
              }
            }
          }
        }
      }
    }
  ''';

  @override
  State<NearbyTransitList> createState() => _NearbyTransitListState();
}

class _NearbyTransitListState extends State<NearbyTransitList> {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(NearbyTransitList.query),
        variables: {'lat': widget.latitude, 'lon': widget.longitude},
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading) {
          return Center(
            child: SpinKitPulse(color: Theme.of(context).primaryColor),
          );
        }

        if (result.hasException) {
          return Center(child: Text('Error: ${result.exception.toString()}'));
        }

        final edges = result.data?['nearest']?['edges'] ?? [];
        if (edges.isEmpty) {
          return const Center(child: Text('No nearby routes found.'));
        }

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: edges.length,
          itemBuilder: (context, index) {
            final place = edges[index]['node']['place'];

            final stoptimes = place['stoptimes'] ?? [];
            if (stoptimes.isEmpty) return const SizedBox.shrink();

            final pattern = place['pattern'];
            final route = pattern['route'];
            final shortName = route['shortName'];
            final longName = route['longName'];
            String displayName = '';

            if (shortName != null) {
              displayName = shortName;
            } else if (longName != null) {
              displayName = longName;
            } else {
              displayName = 'Unknown Route';
            }

            final nextDepartureTime = stoptimes[0]['scheduledDeparture'];
            final currentUTC = DateTime.now().toUtc();
            final currentEST= tz.TZDateTime.from(currentUTC, tz.getLocation('America/New_York'));
            final secSinceMidnight = currentEST.difference(DateTime(currentEST.year, currentEST.month, currentEST.day)).inSeconds;
            final minTillDeparture = ((nextDepartureTime - secSinceMidnight) / 60).floor();


            return ListTile(
              title: Text(displayName ?? ''),
              subtitle: Text(pattern['headsign'] ?? ''),
              trailing: Column(
                children: [
                  Text(
                      '$minTillDeparture' ?? '',
                  style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                  )),
                  const Text('min'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
