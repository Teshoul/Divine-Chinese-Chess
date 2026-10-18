import 'net.dart';

class MatchInfo {
  final NetLink link;
  final bool isHost;
  final bool first;
  final int seed;
  final Map<String, dynamic> params;
  const MatchInfo({
    required this.link,
    required this.isHost,
    required this.first,
    required this.seed,
    required this.params,
  });
}
