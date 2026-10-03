import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const SmartAlarmApp());
}

class DroneInfo {
  final String id;
  final String name;
  LatLng location;
  final String address;
  String time;
  bool isAlarmTriggered;
  final List<String> fireImages;

  DroneInfo({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    required this.time,
    required this.isAlarmTriggered,
    required this.fireImages,
  });
}

class SmartAlarmApp extends StatelessWidget {
  const SmartAlarmApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Alert VTOL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.notoSansTextTheme(Theme.of(context).textTheme),
      ),
      home: const LoginScreen(),
    );
  }
}

// 1. 대원 등록 및 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  bool _isRegistering = false;
  bool _isLoading = false;
  final String baseUrl = 'https://tile-impart-activity.ngrok-free.dev';

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 정보를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대원 등록 성공! 로그인해주세요.')));
        setState(() => _isRegistering = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? '등록 실패')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 통신 오류: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => OtpVerificationScreen(email: email)));
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? '로그인 실패')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 통신 오류: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 64, color: Colors.cyanAccent),
                const SizedBox(height: 16),
                Text(
                  _isRegistering ? '스마트 관제 대원 등록' : '스마트 관제 센터 로그인',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: '대원 이름', labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: '이메일 주소', labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: '비밀번호', labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : (_isRegistering ? _handleRegister : _handleLogin),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text(_isRegistering ? '대원 등록 완료' : '로그인 (OTP 발송)'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isRegistering = !_isRegistering),
                  child: Text(_isRegistering ? '이미 계정이 있으신가요? 로그인하기' : '처음이신가요? 대원 등록(회원가입)', style: const TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. OTP 인증 화면
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  final String baseUrl = 'https://tile-impart-activity.ngrok-free.dev';

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('6자리 인증번호를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SmartAlertHomePage()));
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['detail'] ?? '인증 실패')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 통신 오류: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('대원 보안 OTP 인증', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 64, color: Colors.cyanAccent),
              const SizedBox(height: 16),
              Text('${widget.email} 대원님의\n콘솔(터미널)로 전송된 6자리 인증번호를 입력하세요.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), counterText: ''),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('인증 완료 및 관제 센터 입장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. 페이지 1: 통합 관제 메인 홈 화면
class SmartAlertHomePage extends StatefulWidget {
  const SmartAlertHomePage({Key? key}) : super(key: key);

  @override
  State<SmartAlertHomePage> createState() => _SmartAlertHomePageState();
}

class _SmartAlertHomePageState extends State<SmartAlertHomePage> {
  Timer? _flightTimer;
  Timer? _alarmTimer;
  bool _isFlashing = false;

  final List<DroneInfo> _drones = [
    DroneInfo(
      id: 'drone_1',
      name: 'VTOL 1호기',
      location: const LatLng(37.7853, 126.6775),
      address: '경기도 파주시 탄현면 정찰 구역 A (정상 순찰 중)',
      time: '',
      isAlarmTriggered: false,
      fireImages: ['assets/fire1.jpg', 'assets/fire2.jpg', 'assets/fire3.jpg', 'assets/fire4.jpg'],
    ),
    DroneInfo(
      id: 'drone_2',
      name: 'VTOL 2호기',
      location: const LatLng(37.7920, 126.6850),
      address: '경기도 파주시 탄현면 정찰 구역 B (정상 순찰 중)',
      time: '',
      isAlarmTriggered: false,
      fireImages: ['assets/fire1.jpg', 'assets/fire2.jpg', 'assets/fire3.jpg', 'assets/fire4.jpg'],
    ),
  ];

  int _selectedDroneIndex = 0;

  @override
  void initState() {
    super.initState();
    _startFlightSimulation();
    _startAlarmTriggerTimer();
  }

  void _startFlightSimulation() {
    _flightTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        String currentTime = DateTime.now().toString().substring(0, 19);
        for (int i = 0; i < _drones.length; i++) {
          var drone = _drones[i];
          drone.time = currentTime;
          if (!drone.isAlarmTriggered) {
            double newLat = drone.location.latitude + (i == 0 ? 0.0001 : -0.0001);
            double newLng = drone.location.longitude + 0.0001;
            drone.location = LatLng(newLat, newLng);
          }
        }
      });
    });
  }

  void _startAlarmTriggerTimer() {
    Timer(const Duration(seconds: 10), () {
      setState(() {
        _drones[0].isAlarmTriggered = true;
      });
      _alarmTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        setState(() {
          _isFlashing = !_isFlashing;
        });
      });
    });
  }

  @override
  void dispose() {
    _flightTimer?.cancel();
    _alarmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDrone = _drones[_selectedDroneIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alert 관제 센터', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          ..._drones.asMap().entries.map((entry) {
            int idx = entry.key;
            var d = entry.value;
            bool isChosen = (_selectedDroneIndex == idx);
            bool isAlerting = d.isAlarmTriggered;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAlerting && _isFlashing ? Colors.red : (isChosen ? Colors.cyanAccent : Colors.grey[800]),
                  foregroundColor: isChosen || (isAlerting && _isFlashing) ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  setState(() => _selectedDroneIndex = idx);
                  if (d.isAlarmTriggered) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EmergencyAlertScreen(drone: d)),
                    );
                  }
                },
                child: Text(d.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: activeDrone.location,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_alarm_app',
                ),
                MarkerLayer(
                  markers: _drones.asMap().entries.map((entry) {
                    int index = entry.key;
                    DroneInfo drone = entry.value;
                    bool isSelected = (_selectedDroneIndex == index);
                    bool flash = drone.isAlarmTriggered && _isFlashing;

                    return Marker(
                      point: drone.location,
                      width: 150,
                      height: 55,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDroneIndex = index);
                          if (drone.isAlarmTriggered) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EmergencyAlertScreen(drone: drone)),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: flash ? Colors.red.withOpacity(0.95) : const Color(0xFF0F172A).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: flash ? Colors.yellowAccent : (isSelected ? Colors.amberAccent : Colors.cyanAccent),
                              width: flash ? 2.5 : 1.2,
                            ),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                drone.isAlarmTriggered ? Icons.warning_amber_rounded : Icons.flight,
                                color: flash ? Colors.yellowAccent : Colors.cyanAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(drone.name, style: TextStyle(color: flash ? Colors.yellow : Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                  Text('위도:${drone.location.latitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 8)),
                                  Text('경도:${drone.location.longitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 8)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.airplanemode_active, color: Colors.cyanAccent, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '실시간 관제 - ${activeDrone.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (activeDrone.isAlarmTriggered)
                          SizedBox(
                            height: 30,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => EmergencyAlertScreen(drone: activeDrone)));
                              },
                              child: const Text('🚨 긴급 전환', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('정찰 위치: ${activeDrone.address}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('실시간 시간: ${activeDrone.time}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('정밀 좌표: 위도 ${activeDrone.location.latitude.toStringAsFixed(5)} / 경도 ${activeDrone.location.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('🌡️ 21.5°C', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text('💨 3.4m/s(서북풍)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text('💧 습도 42%', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: activeDrone.isAlarmTriggered
                          ? const Text('🚨 [긴급] 화재 징후 포착! 상단 버튼이나 마커를 누르세요!', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))
                          : const Text('🟢 드론 상공 정상 정찰 중 (10초 뒤 자동 경보 시뮬레이션)', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. 페이지 2: 비상 경보 관제 화면 (사진 2x2 정사각형 격자 구조 반영)
class EmergencyAlertScreen extends StatefulWidget {
  final DroneInfo drone;
  const EmergencyAlertScreen({Key? key, required this.drone}) : super(key: key);

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _visibleStageCount = 1;
  Timer? _stageTimer;

  final List<Map<String, String>> _stages = [
    {
      "photoLabel": "사진 1 (탐지)",
      "title": "[상황보고 1] 초기 열원 감지",
      "desc": "• EO/IR 광학 카메라 가동\n• 파주 탄현면 A-3 고온 열원 포착 (신뢰도 99.4%)\n• 행동지침: 정찰 고도 유지 및 스캔 모드 전환"
    },
    {
      "photoLabel": "사진 2 (분석)",
      "title": "[상황보고 2] 정밀 열화상 분석",
      "desc": "• 중심부 온도 680°C 도달\n• 서북풍(3.4m/s) 연동 확산 예측 완료\n• 행동지침: 확산 예상 경로 차단선 설정"
    },
    {
      "photoLabel": "사진 3 (통보)",
      "title": "[상황보고 3] 소방항공본부 릴레이",
      "desc": "• 지휘 통제소 자동 경보 긴급 송신\n• 소방헬기 출동 대기 지령 하달\n• 행동지침: 긴급 딜레이 발령 및 데이터 공유"
    },
    {
      "photoLabel": "사진 4 (타격)",
      "title": "[상황보고 4] 진화 드론 타격 유도",
      "desc": "• VTOL 2호기 소화탄 좌표(A-3) 조준\n• 현장 대원 통제선 설정 완료\n• 행동지침: 소화탄 투하 카운트다운 시작"
    },
  ];

  final List<String> _stageCurrentText = ["", "", "", ""];
  Timer? _charTimer;
  int _activeStage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _playAlarm();
    _startSequentialStageTimer();
    _startTypingForStage(0);
  }

  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alarm.mp3'));
    } catch (e) {
      print('알람 재생 에러: $e');
    }
  }

  void _startSequentialStageTimer() {
    _stageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_visibleStageCount < 4) {
        setState(() {
          _visibleStageCount++;
          _activeStage = _visibleStageCount - 1;
        });
        _startTypingForStage(_activeStage);
      } else {
        _stageTimer?.cancel();
      }
    });
  }

  void _startTypingForStage(int stageIdx) {
    _charTimer?.cancel();
    final fullText = "${_stages[stageIdx]["title"]}\n${_stages[stageIdx]["desc"]}\n";
    int localCharIndex = 0;

    _charTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (localCharIndex < fullText.length) {
        setState(() {
          _stageCurrentText[stageIdx] += fullText[localCharIndex];
          localCharIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stageTimer?.cancel();
    _charTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('🚨 긴급 비상관제 - ${widget.drone.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        backgroundColor: Colors.red[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 비상 정보 카드
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('위치: ${widget.drone.address}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('대응 단계: $_visibleStageCount / 4단계 진행 중', style: const TextStyle(color: Colors.yellowAccent, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 📸 2x2 정사각형 그리드 사진 분할 (상단 2개, 하단 2개)
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildPhotoTile(0)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPhotoTile(1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildPhotoTile(2)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPhotoTile(3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 📝 하단: 넉넉해진 공간의 타이핑 로그 창
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _visibleStageCount,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        _stageCurrentText[index],
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, height: 1.3, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2x2 각 사진 타일 위젯
  Widget _buildPhotoTile(int index) {
    bool isVisible = index < _visibleStageCount;
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.15,
      duration: const Duration(milliseconds: 800),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isVisible ? Colors.redAccent : Colors.grey[800]!, width: isVisible ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVisible)
                Image.asset(widget.drone.fireImages[index], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
              else
                Center(child: Text('대기중\n(${index + 1})', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11))),
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: isVisible ? Colors.red : Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    _stages[index]["photoLabel"]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}