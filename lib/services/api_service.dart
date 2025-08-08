import 'package:flutter/cupertino.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mass_transit/constants.dart';

final HttpLink _httpLink = HttpLink(
  Constants.otpUrl,
);

final ValueNotifier<GraphQLClient> client = ValueNotifier(
  GraphQLClient(
    cache: GraphQLCache(store: InMemoryStore()),
    link: _httpLink,
  ),
);

final nearbyDeparturesQuery = gql(r'''
  query GetNearbyDepartures($lat: Float!, $lon: Float!) {
  nearest(
    lat: $lat, 
    lon: $lon,
    filterByPlaceTypes: DEPARTURE_ROW
  ) {
    edges {
      node {
        id
        distance
        place {
          id
          __typename
          lat
          lon
          ...on DepartureRow {
            pattern {
              headsign
              route {
                shortName
                longName
              }
            }
            stoptimes {
              scheduledArrival
              timepoint
            }
          }
        }
      }
    }
  }
}
''');

getNearbyDepartures(double lat, double lon) {
  return client.value.query(
    QueryOptions(
      document: nearbyDeparturesQuery,
      variables: {
        'lat': lat,
        'lon': lon,
      },
    ),
  );
}