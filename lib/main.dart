import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mass_transit/nearby_transit_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'constants.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();

  final HttpLink httpLink = HttpLink(Constants.otpUrl);

  ValueNotifier<GraphQLClient> client = ValueNotifier(
    GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(store: InMemoryStore()),
    ),
  );

  tzdata.initializeTimeZones(); // Initialize timezone database

  runApp(
    GraphQLProvider(
      client: client,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheetController;

  late final MapController _mapController;

  double? lat;
  double? lon;

  final double _minSheetSize = 0.2;
  double? _sheetSize;

  LatLng? _currentLocation;

  @override
  void initState() {
    _sheetSize = _minSheetSize;
    _sheetController = BottomSheet.createAnimationController(this);
    _mapController = MapController();
    _getCurrentLocation();
    super.initState();

    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd) {
        // Update the nearby transit list when the map stops moving
        setState(() {
          lat = _mapController.camera.center.latitude;
          lon = _mapController.camera.center.longitude;
        });
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    if (_currentLocation == null) {
      return Center(child: SpinKitPulse(color: Theme.of(context).primaryColor));
    }
    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height * (1.0 - _sheetSize!) + 25,
              child:
              Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 10,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ), //disables rotation
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.maptiler.com/maps/basic-v2-light/{z}/{x}/{y}.png?key=${Constants.mapTilerKey}',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                      Transform.translate(
                        offset: Offset(0, MediaQuery.of(context).systemGestureInsets.bottom - 20), //Flutter weirdly adds a bottom padding the height of the nav bar to the safe area. This causes a nav bar level of space to be put between the sheet and the attributes. The 20px is cause it got partially hidden when I tried fixing it this way.
                        child: RichAttributionWidget(
                          // Include a stylish prebuilt attribution widget that meets all requirements
                          attributions: [
                            LogoSourceAttribution(
                              Image.network(
                                'https://media.maptiler.com/old/mediakit/logo/maptiler-logo.png',
                              ),
                              onTap:
                                  () => launchUrl(
                                    Uri.parse('https://www.maptiler.com'),
                                  ),
                            ),
                            TextSourceAttribution(
                              'MapTiler',
                              onTap:
                                  () => launchUrl(
                                    Uri.parse(
                                      'https://www.maptiler.com/copyright',
                                    ),
                                  ),
                            ),
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap:
                                  () => launchUrl(
                                    Uri.parse(
                                      'https://openstreetmap.org/copyright',
                                    ),
                                  ),
                            ),
                          ],
                          showFlutterMapAttribution: false,
                          alignment: AttributionAlignment.bottomRight,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withAlpha(150),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              setState(() {
                _sheetSize = notification.extent;
              });
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: _minSheetSize,
              minChildSize: _minSheetSize,
              maxChildSize: 1.0,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    borderRadius: //Maybe add an animation here for when you do scroll it to the top
                        _sheetSize == 1.0
                            ? BorderRadius.zero
                            : BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child:
                      lat != null && lon != null
                        ? NearbyTransitList(
                            latitude: lat!,
                            longitude: lon!,
                            scrollController: scrollController,
                          )
                        : Center(
                            child: SpinKitPulse(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
