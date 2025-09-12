import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  final String espIP = "192.168.4.1"; // ESP8266 IP
  
  // Helper to send commands to the ESP8266
  Future<void> sendCommand(String command) async {
    try {
      final url = Uri.parse("http://$espIP/command?action=$command");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        debugPrint("✅ Command sent: $command");
      } else {
        debugPrint("❌ Failed to send command: $command");
      }
    } catch (e) {
      debugPrint("❌ Error sending command: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🤖 Robot Control"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // D-pad for directional control
            _buildDpad(context),
            const SizedBox(height: 40),
            // Stop and Emergency buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDpad(BuildContext context) {
    return Column(
      children: [
        // Forward button
        SizedBox(
          width: 80,
          height: 80,
          child: ElevatedButton(
            onPressed: () => sendCommand("forward"),
            child: const Icon(Icons.arrow_upward, size: 40),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left button
            SizedBox(
              width: 80,
              height: 80,
              child: ElevatedButton(
                onPressed: () => sendCommand("left"),
                child: const Icon(Icons.arrow_back, size: 40),
              ),
            ),
            const SizedBox(width: 20),
            // Stop button (in the middle)
            SizedBox(
              width: 80,
              height: 80,
              child: ElevatedButton(
                onPressed: () => sendCommand("stop"),
                child: const Icon(Icons.pause, size: 40),
              ),
            ),
            const SizedBox(width: 20),
            // Right button
            SizedBox(
              width: 80,
              height: 80,
              child: ElevatedButton(
                onPressed: () => sendCommand("right"),
                child: const Icon(Icons.arrow_forward, size: 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Backward button
        SizedBox(
          width: 80,
          height: 80,
          child: ElevatedButton(
            onPressed: () => sendCommand("backward"),
            child: const Icon(Icons.arrow_downward, size: 40),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => sendCommand("stop"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text("STOP", style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => sendCommand("emergency_stop"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text("EMERGENCY STOP", style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
