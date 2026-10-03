import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const SmartAlertApp());
}

class SmartAlertApp extends StatelessWidget {
  const SmartAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Alert VTOL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF141821),
        fontFamily: 'Noto Sans KR',
        textTheme: GoogleFonts.notoSansKrTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  LatLng _dronePosition = const LatLng(37.7785, 126.6922);
  final List<LatLng> _flightPath = [const LatLng(37.7785, 126.6922)];
  Timer? _mockFlightTimer;
  Timer? _clockTimer;
  final MapController _mapController = MapController();

  String _currentTime = '';
  String _liveWeather = '맑음 (기온: 21.5°C, 풍속: 1.2m/s)';

  final List<Map<String, dynamic>> devices = [
    {
      'id': 'VTOL-01',
      'name': 'AI VTOL 정찰 드론 1호기',
      'type': 'DRONE',
      'location': '경기도 파주시 탄현면',
      'status': 'NORMAL',
      'battery': 85,
    },
    {
      'id': 'IOT-H-02',
      'name': '다솜초 2학년 2반 거치대',
      'type': 'IOT_EXTINGUISHER',
      'location': '경기도 고양시 일산동구 숲속마을로 139',
      'status': 'NORMAL',
      'battery': 98,
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _connectWebSocket();
    _startSimulatedFlight();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      int sec = now.second;
      if (sec % 10 < 5) {
        _liveWeather = '맑음 ☀️ (기온: 21.5°C, 풍속: 1.2m/s)';
      } else {
        _liveWeather = '구름 조금 ⛅ (기온: 21.4°C, 풍속: 1.5m/s)';
      }
    });
  }

  void _startSimulatedFlight() {
    _mockFlightTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _dronePosition = LatLng(
          _dronePosition.latitude + 0.0008,
          _dronePosition.longitude + 0.0005,
        );
        _flightPath.add(_dronePosition);
      });

      try {
        _mapController.move(_dronePosition, 14.0);
      } catch (_) {}
    });
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
       Uri.parse('wss://tile-impart-activity.ngrok-free.dev/ws/alerts'),
      );

      setState(() => _isConnected = true);

      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['event'] == 'EMERGENCY_ALERT') {
          _triggerEmergencyAlert(data);
        }
      }, onError: (error) {
        setState(() => _isConnected = false);
      }, onDone: () {
        setState(() => _isConnected = false);
      });
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _triggerEmergencyAlert(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyScreen(
          alertData: {
            ...data,
            'lat': _dronePosition.latitude,
            'lng': _dronePosition.longitude,
            'timestamp': _currentTime,
            'gps': '${_dronePosition.latitude.toStringAsFixed(4)}, ${_dronePosition.longitude.toStringAsFixed(4)}',
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mockFlightTimer?.cancel();
    _clockTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF202632),
        title: Row(
          children: [
            const Text(
              'Smart Alert 관제 센터',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.greenAccent : Colors.grey,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              '🕒 $_currentTime',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert, color: Colors.redAccent),
            onPressed: () {
              _triggerEmergencyAlert({
                'title': 'AI VTOL 리얼 산불 조기감지 및 4분할 AI 분석 경보',
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 340,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(37.7785, 126.6922),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_alarm_app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _flightPath,
                      strokeWidth: 4.0,
                      color: Colors.cyanAccent,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _dronePosition,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.cyan,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                        child: const Icon(
                          Icons.flight_takeoff,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    Marker(
                      point: const LatLng(37.6695, 126.8122),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black45, blurRadius: 4)
                          ],
                        ),
                        child: const Icon(
                          Icons.fire_extinguisher,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final deviceData = devices[index];
                final isDrone = deviceData['type'] == 'DRONE';

                return Card(
                  color: const Color(0xFF202632),
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      isDrone ? Icons.flight_takeoff : Icons.fire_extinguisher,
                      color: Colors.cyanAccent,
                      size: 32,
                    ),
                    title: Text(
                      deviceData['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isDrone
                          ? '위치: ${deviceData['location']} | 실시간 시각: $_currentTime\n기상 상태: $_liveWeather\n실시간 GPS 좌표: ${_dronePosition.latitude.toStringAsFixed(4)}, ${_dronePosition.longitude.toStringAsFixed(4)} (이동 중) | 배터리: ${deviceData['battery']}%'
                          : '위치: ${deviceData['location']}\n배터리: ${deviceData['battery']}%',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text('정상 정찰', style: TextStyle(color: Colors.green, fontSize: 12)),
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

class EmergencyScreen extends StatefulWidget {
  final Map<String, dynamic> alertData;

  const EmergencyScreen({super.key, required this.alertData});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  html.AudioElement? _sirenAudio;
  bool _isPlayingSiren = false;

  // 🔥 행님이 올리신 로컬 파일 4장 완벽 연동 (외부 링크 0%)
  final List<Map<String, String>> _fireStages = [
    {
      'image': 'assets/fire1.jpg',
      'title': '상황 1: 초기 연기 감지',
      'ai_analysis': 'AI 판독: 북서쪽 능선 미세 연기 포착 (확률 94%)',
    },
    {
      'image': 'assets/fire2.jpg',
      'title': '상황 2: 화염 확산 진행',
      'ai_analysis': 'AI 판독: 풍속 영향으로 화염 면적 급격 확산 중',
    },
    {
      'image': 'assets/fire3.jpg',
      'title': '상황 3: 본격 산불 진화 필요',
      'ai_analysis': 'AI 판독: 능선 전체 화재 경보 발령 수준 도달',
    },
    {
      'image': 'assets/fire4.jpg',
      'title': '상황 4: AI 정밀 타겟팅 완료',
      'ai_analysis': 'AI 판독: 소방청 진화 드론 및 소방차 유도 완료',
    },
  ];

  int _visibleStageCount = 1;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _initAndPlaySiren();

    _revealTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        if (_visibleStageCount < 4) {
          _visibleStageCount++;
        } else {
          _revealTimer?.cancel();
        }
      });
    });
  }

  void _initAndPlaySiren() {
    try {
      _sirenAudio = html.AudioElement('https://actions.google.com/sounds/v1/alarms/emergency_alarm.ogg')
        ..loop = true;
      
      _sirenAudio!.play().then((_) {
        if (mounted) setState(() => _isPlayingSiren = true);
      }).catchError((_) {
        if (mounted) setState(() => _isPlayingSiren = false);
      });
    } catch (_) {}
  }

  void _toggleSiren() {
    if (_sirenAudio == null) return;
    if (_isPlayingSiren) {
      _sirenAudio!.pause();
      setState(() => _isPlayingSiren = false);
    } else {
      _sirenAudio!.play().then((_) {
        setState(() => _isPlayingSiren = true);
      });
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    try {
      _sirenAudio?.pause();
      _sirenAudio = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double lat = widget.alertData['lat'] ?? 37.7785;
    final double lng = widget.alertData['lng'] ?? 126.6922;
    final String timestamp = widget.alertData['timestamp'] ?? '지금';
    final String gpsStr = widget.alertData['gps'] ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Smart Alert 위급상황! 리얼 산불 4분할 AI 비전 분석 경보발생!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlayingSiren ? Colors.amber : Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _toggleSiren,
                    icon: Icon(_isPlayingSiren ? Icons.volume_up : Icons.volume_off),
                    label: Text(_isPlayingSiren ? '사이렌 울리는 중 (클릭시 정지)' : '사이렌 켜기 (클릭)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: 4,
                        itemBuilder: (context, index) {
                          bool isUnlocked = index < _visibleStageCount;
                          final stageInfo = _fireStages[index];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isUnlocked
                                    ? Image.asset(
                                        stageInfo['image']!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.black87,
                                          child: const Center(
                                            child: Text('이미지 로딩 실패\n(확장자 .jpg 확인)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 10)),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.black54,
                                        child: Center(
                                          child: Text(
                                            '상황 ${index + 1}\n(5초 간격 AI 분석 대기...)',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isUnlocked ? Colors.red.withOpacity(0.85) : Colors.grey.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isUnlocked ? stageInfo['title']! : '상황 ${index + 1} (대기)',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                if (isUnlocked)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      color: Colors.black.withOpacity(0.75),
                                      child: Text(
                                        stageInfo['ai_analysis']!,
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 14.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.smart_alarm_app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('• 경보유형: ${widget.alertData['title'] ?? '리얼 산불 감지 경보'}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('• 발생시각: $timestamp', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('• GPS 좌표: $gpsStr', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('경보 해제 및 확인 (사이렌 정지)', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}