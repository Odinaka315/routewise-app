import 'models.dart';

// Demo data copied from the Figma design. Replace with real API / database
// results when you connect a backend.

const List<Stop> sampleStops = [
  Stop(uid: 1, name: 'Maryland Mall', address: '350–360 Ikorodu Road, Maryland'),
  Stop(uid: 2, name: 'Allen Avenue Hub', address: '21 Allen Avenue, Ikeja'),
  Stop(uid: 3, name: 'Computer Village', address: 'Otigba Street, Ikeja'),
  Stop(uid: 4, name: 'Murtala Muhammed Airport', address: 'Airport Road, Ikeja'),
  Stop(uid: 5, name: 'Ogba Retail Centre', address: 'Ijaiye Road, Ogba'),
  Stop(uid: 6, name: 'Yaba Dispatch Point', address: 'Herbert Macaulay Way, Yaba'),
];

const List<Trip> sampleTrips = [
  Trip(
    id: 't1',
    title: 'Monday mainland run',
    stops: 8,
    distance: '34.6 km',
    time: '1 hr 42 min',
    date: 'Today, 7:24 am',
    starred: true,
    savedPercent: '24%',
  ),
  Trip(
    id: 't2',
    title: 'Island pharmacy drops',
    stops: 12,
    distance: '48.2 km',
    time: '2 hr 18 min',
    date: 'Yesterday, 2:10 pm',
    starred: true,
    savedPercent: '31%',
  ),
  Trip(
    id: 't3',
    title: 'Ikeja afternoon route',
    stops: 6,
    distance: '21.8 km',
    time: '1 hr 06 min',
    date: '18 Oct, 1:45 pm',
    savedPercent: '18%',
    editedFrom: 'Monday mainland run',
  ),
  Trip(
    id: 't4',
    title: 'Lekki customer returns',
    stops: 9,
    distance: '—',
    time: '—',
    date: '16 Oct, 9:12 am',
    failed: true,
  ),
];

const List<RouteRun> sampleRuns = [
  RouteRun(
    date: 'Today, 7:24 am',
    meta: 'Balanced · One-way',
    distance: '34.6 km',
    time: '1 hr 42 min',
    summary: '24% saved',
    ready: true,
  ),
  RouteRun(
    date: '20 Oct, 8:16 am',
    meta: 'Fastest · One-way',
    distance: '37.2 km',
    time: '1 hr 35 min',
    summary: '19% saved',
    ready: true,
  ),
  RouteRun(
    date: '18 Oct, 4:42 pm',
    meta: 'Balanced · One-way',
    distance: '—',
    time: '—',
    summary: 'Road data unavailable',
    ready: false,
  ),
];

/// Distance / time between consecutive stops on the route result screen.
const List<String> sampleLegs = [
  '6.4 km · 18 min',
  '4.2 km · 12 min',
  '9.8 km · 26 min',
];
