import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async'; 
import 'dart:math'; // For Path Preview

// ====================================================================
// --- Models for Recorded Movement Sequence ---
// ====================================================================

// Stores a single command and the time delay (in ms) before it runs.
class SequenceCommand {
  final String command;
  final int delayMs;

  SequenceCommand({required this.command, required this.delayMs});

  Map<String, dynamic> toJson() => {
        'command': command,
        'delayMs': delayMs,
      };

  factory SequenceCommand.fromJson(Map<String, dynamic> json) => SequenceCommand(
        command: json['command'] as String,
        delayMs: json['delayMs'] as int,
      );
  
  // Gets the opposite command for path reversal
  String get reverseCommand {
    switch (command.toLowerCase()) {
      case 'forward': return 'backward';
      case 'backward': return 'forward';
      case 'left': return 'right';
      case 'right': return 'left';
      default: return 'stop'; // Stop is usually its own reverse
    }
  }
}

// Stores an entire named sequence of commands.
class MovementSequence {
  final String name;
  final List<SequenceCommand> commands;
  
  // New Looping/Automation Properties
  final bool isLooped;
  final bool isIndefinite;
  final int loopCount;
  final bool startReversed;

  MovementSequence({
    required this.name,
    required this.commands,
    this.isLooped = false,
    this.isIndefinite = false,
    this.loopCount = 1,
    this.startReversed = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'commands': commands.map((c) => c.toJson()).toList(),
        'isLooped': isLooped,
        'isIndefinite': isIndefinite,
        'loopCount': loopCount,
        'startReversed': startReversed,
      };

  factory MovementSequence.fromJson(Map<String, dynamic> json) => MovementSequence(
        name: json['name'] as String,
        commands: (json['commands'] as List)
            .map((item) => SequenceCommand.fromJson(item))
            .toList(),
        isLooped: json['isLooped'] as bool? ?? false,
        isIndefinite: json['isIndefinite'] as bool? ?? false,
        loopCount: json['loopCount'] as int? ?? 1,
        startReversed: json['startReversed'] as bool? ?? false,
      );
}

// ====================================================================
// --- CONSTANT ICON MAP (Helper for Storing/Retrieving Icons) ---
// ====================================================================

class SupportedIcons {
  static const Map<String, IconData> iconMap = {
    'arrow_upward': Icons.arrow_upward,
    'arrow_downward': Icons.arrow_downward,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'pause': Icons.pause,
    'stop': Icons.stop,
    'warning': Icons.warning,
    'lightbulb': Icons.lightbulb,
    'code': Icons.code,
    'home': Icons.home,
    'play_circle': Icons.play_circle,
    'settings_power': Icons.settings_power,
    'radio': Icons.radio_button_checked,
  };

  static IconData? getIcon(String key) {
    return iconMap[key];
  }

  static String? getKey(IconData icon) {
    for (var entry in iconMap.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key;
      }
    }
    return null;
  }
}

// ====================================================================
// --- Model for a Custom Robot Command Button ---
// ====================================================================
class CommandButton {
  final String label;
  final String command;
  final String? iconKey;
  final String? imageUrl;
  final String? buttonColorHex; // New property for button color

  CommandButton({
    required this.label,
    required this.command,
    this.iconKey,
    this.imageUrl,
    this.buttonColorHex,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'command': command,
        'iconKey': iconKey,
        'imageUrl': imageUrl,
        'buttonColorHex': buttonColorHex,
      };

  factory CommandButton.fromJson(Map<String, dynamic> json) => CommandButton(
        label: json['label'] as String,
        command: json['command'] as String,
        iconKey: json['iconKey'] as String?,
        imageUrl: json['imageUrl'] as String?,
        buttonColorHex: json['buttonColorHex'] as String?,
      );

  IconData? get iconData => iconKey != null ? SupportedIcons.getIcon(iconKey!) : null;

  Color get color {
    if (buttonColorHex != null) {
      // Convert hex string (e.g., #FF0000) to Color
      try {
        String hex = buttonColorHex!.replaceAll('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex'; // Add alpha if missing
        }
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return Colors.deepOrange.shade600; // Fallback to new theme color
      }
    }
    // Default color logic
    if (command.toLowerCase() == 'stop' || command.toLowerCase().contains('emergency')) {
      return Colors.red.shade700; // Keep critical colors red
    }
    return Colors.deepOrange.shade600; // New default action/dpad color
  }
}

// ====================================================================
// --- Main Control Screen ---
// ====================================================================
enum RecordingState { stopped, recording, paused }

class RobotControlScreen extends StatefulWidget {
  final bool embedded;
  const RobotControlScreen({super.key, this.embedded = false});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  static const String _prefsKey = 'customRobotCommands';
  static const String _sequencePrefsKey = 'robotMovementSequences';
  final String espIP = "192.168.4.1";

  // Default Commands
  final List<CommandButton> _defaultDpadCommands = [
    CommandButton(label: 'Forward', command: 'forward', iconKey: 'arrow_upward'),
    CommandButton(label: 'Backward', command: 'backward', iconKey: 'arrow_downward'),
    CommandButton(label: 'Left', command: 'left', iconKey: 'arrow_back'),
    CommandButton(label: 'Right', command: 'right', iconKey: 'arrow_forward'),
    CommandButton(label: 'STOP', command: 'stop', iconKey: 'pause', buttonColorHex: '#B71C1C'),
  ];
  final List<CommandButton> _defaultActionCommands = [
    CommandButton(label: 'Lights On', command: 'lights_on', iconKey: 'lightbulb', buttonColorHex: '#FFC107'),
    CommandButton(label: 'EMERGENCY STOP', command: 'emergency_stop', iconKey: 'warning', buttonColorHex: '#D32F2F'),
  ];

  List<CommandButton> _customDpadCommands = [];
  List<CommandButton> _customActionCommands = [];
  List<MovementSequence> _savedSequences = [];
  bool _isLoading = true;

  // --- State Variables for Recording & Playback ---
  RecordingState _recordingState = RecordingState.stopped;
  List<SequenceCommand> _currentRecording = [];
  DateTime? _lastCommandTime;
  bool _isPlaybackActive = false; // New state to control UI during playback

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- Persistence & Initialization ---

  Future<void> _loadAllData() async {
    await _loadCustomCommands();
    await _loadSequences();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCustomCommands() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_prefsKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _customDpadCommands = (jsonMap['dpad'] as List)
            .map((item) => CommandButton.fromJson(item))
            .toList();
        _customActionCommands = (jsonMap['actions'] as List)
            .map((item) => CommandButton.fromJson(item))
            .toList();
      } catch (e) {
        _setDefaults();
        _showSnackBar("⚠️ Failed to load custom settings. Restored to defaults.");
      }
    } else {
      _setDefaults();
    }
  }

  Future<void> _saveCustomCommands() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {
      'dpad': _customDpadCommands.map((c) => c.toJson()).toList(),
      'actions': _customActionCommands.map((c) => c.toJson()).toList(),
    };
    final String jsonString = json.encode(jsonMap);
    await prefs.setString(_prefsKey, jsonString);
    _showSnackBar("💾 Controls saved successfully.");
  }

  void _setDefaults() {
    // Deep copy defaults
    _customDpadCommands = _defaultDpadCommands.map((c) => CommandButton.fromJson(c.toJson())).toList();
    _customActionCommands = _defaultActionCommands.map((c) => CommandButton.fromJson(c.toJson())).toList();
    _saveCustomCommands();
  }

  Future<void> _loadSequences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_sequencePrefsKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        _savedSequences = jsonList.map((item) => MovementSequence.fromJson(item)).toList();
      } catch (e) {
        _savedSequences = [];
      }
    }
  }

  Future<void> _saveSequences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        _savedSequences.map((s) => s.toJson()).toList();
    await prefs.setString(_sequencePrefsKey, json.encode(jsonList));
  }

  // --- Communication & Feedback ---

  Future<void> sendCommand(String command) async {
    if (command.isEmpty) {
      _showSnackBar("❌ Command string is empty.");
      return;
    }

    try {
      final url = Uri.parse("http://$espIP/command?action=$command");
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      String message;
      if (response.statusCode == 200) {
        message =
            "✅ Command '$command' sent.";
      } else {
        message =
            "❌ Failed to send command '$command'. Status: ${response.statusCode}.";
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar("❌ Error sending command to $espIP: $e");
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Recording Logic ---

  bool _isMovementCommand(String command) {
    final movementCommands = ['forward', 'backward', 'left', 'right', 'stop'];
    return movementCommands.contains(command.toLowerCase());
  }

  Future<void> _sendCommandAndRecord(String command) async {
    // 1. Send the command immediately
    await sendCommand(command);

    // 2. Record the command if active and it's a movement command
    if (_recordingState == RecordingState.recording && _isMovementCommand(command)) {
      final now = DateTime.now();
      int delayMs = 0;

      if (_lastCommandTime != null) {
        delayMs = now.difference(_lastCommandTime!).inMilliseconds;
      }
      
      // Ensure the delay is only recorded BEFORE the command
      // The first command's delay will be 0, which is correct.
      // We only store the command, the delay is the wait time BEFORE it.
      _currentRecording.add(SequenceCommand(command: command, delayMs: delayMs));
      _lastCommandTime = now;
      _showSnackBar("Command '$command' recorded with ${delayMs}ms delay. Total steps: ${_currentRecording.length}");
    }
  }

  void _toggleRecording() {
    setState(() {
      if (_recordingState == RecordingState.stopped) {
        _recordingState = RecordingState.recording;
        _currentRecording = [];
        _lastCommandTime = DateTime.now();
        _showSnackBar("🔴 Recording started!");
      } else if (_recordingState == RecordingState.recording) {
        _recordingState = RecordingState.paused;
        _lastCommandTime = null;
        _showSnackBar("⏸️ Recording paused.");
      } else if (_recordingState == RecordingState.paused) {
        _recordingState = RecordingState.recording;
        _lastCommandTime = DateTime.now();
        _showSnackBar("▶️ Recording resumed.");
      }
    });
  }

  void _endRecording() {
    setState(() {
      _recordingState = RecordingState.stopped;
    });

    if (_currentRecording.length < 2) {
      _showSnackBar("Recording ended. Sequence too short to save (min 2 steps required).");
      _currentRecording = [];
      return;
    }

    _showSaveSequenceDialog(context);
  }

  // Helper to generate the reverse sequence
  List<SequenceCommand> _getReversedSequence(List<SequenceCommand> original) {
    // 1. Filter out all 'stop' commands, as they tend to clutter reversal.
    // 2. Reverse the list of commands.
    // 3. Reverse the commands (forward -> backward, left -> right).
    
    final List<SequenceCommand> filtered = original.where((c) => c.command.toLowerCase() != 'stop').toList();
    
    if (filtered.isEmpty) return [];

    final List<SequenceCommand> reversedCommands = [];

    // Reverse the commands and use the delay of the command being reversed
    for (int i = filtered.length - 1; i >= 0; i--) {
        final originalCmd = filtered[i];
        final int delay = originalCmd.delayMs; 
        
        reversedCommands.add(SequenceCommand(
          command: originalCmd.reverseCommand,
          delayMs: delay,
        ));
    }
    
    // The very first command in the reversed list should have a 0 delay.
    if (reversedCommands.isNotEmpty) {
      reversedCommands.first = SequenceCommand(
        command: reversedCommands.first.command,
        delayMs: 0,
      );
    }

    return reversedCommands;
  }
  
  // --- Path Save Dialog ---

  Future<void> _showSaveSequenceDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final reverseSequence = _getReversedSequence(_currentRecording);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Movement Sequence (Path)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Sequence Name'),
            ),
            const SizedBox(height: 10),
            Text('Steps recorded: ${_currentRecording.length}'),
            Text('Auto-generated Reverse Steps: ${reverseSequence.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentRecording = [];
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final newSequence = MovementSequence(
                  name: nameController.text.trim(),
                  commands: _currentRecording,
                );
                setState(() {
                  _savedSequences.add(newSequence);
                  _saveSequences();
                });
                _currentRecording = [];
                Navigator.pop(context);
              }
            },
            child: const Text('Save Path'),
          ),
        ],
      ),
    );
  }

  // --- Playback Logic ---

  Future<void> _playbackSequence(MovementSequence sequence) async {
    if (_isPlaybackActive) return;

    setState(() {
      _isPlaybackActive = true;
    });

    final List<SequenceCommand> forwardPath = sequence.commands;
    final List<SequenceCommand> reversePath = _getReversedSequence(forwardPath);
    
    List<SequenceCommand> currentPath;
    int loopCounter = 0;
    
    _showSnackBar("▶️ Starting playback for '${sequence.name}'...");

    while (sequence.isIndefinite || loopCounter < sequence.loopCount) {
      // 1. Determine which path to run (Normal or Reverse)
      bool isNormal = true;
      if (sequence.isLooped) {
        if (sequence.startReversed) {
          isNormal = (loopCounter % 2 == 1); // Reverse -> Normal -> Reverse...
        } else {
          isNormal = (loopCounter % 2 == 0); // Normal -> Reverse -> Normal...
        }
      }
      
      currentPath = isNormal ? forwardPath : reversePath;
      
      // Log the path being run
      _showSnackBar(sequence.isLooped
          ? "Loop ${loopCounter + 1}/${sequence.isIndefinite ? '∞' : sequence.loopCount} | Executing: ${isNormal ? 'Normal Path' : 'Reverse Path'}"
          : "Executing: Normal Path");
      
      // 2. Execute the commands in the chosen path
      for (int i = 0; i < currentPath.length; i++) {
        final cmd = currentPath[i];
        
        // If the path is not the first, the first command has the previous path's final delay
        if (cmd.delayMs > 0) {
          await Future.delayed(Duration(milliseconds: cmd.delayMs));
        }

        await sendCommand(cmd.command);

        if (!mounted || !_isPlaybackActive) {
          _showSnackBar("🛑 Playback manually stopped.");
          setState(() { _isPlaybackActive = false; });
          return;
        }
      }
      
      // 3. Increment counter and check termination
      if (!sequence.isIndefinite) {
        loopCounter++;
        if (loopCounter >= sequence.loopCount) {
          break; // Exit while loop if all loops are done
        }
      }
      
      // Wait a short break between full loops
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // --- Playback Finished ---
    _showSnackBar("✅ Playback for '${sequence.name}' finished.");
    setState(() {
      _isPlaybackActive = false;
    });
  }
  
  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryColor = Colors.teal;
    final Color appBarColor = Colors.teal.shade800;

    final Widget bodyContent = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPlaybackActive
              ? _buildPlaybackStatus()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildRecordingPanel(),
                        const SizedBox(height: 30),

                        Text(
                          "Directional Controls",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        const Divider(height: 20, thickness: 2, indent: 50, endIndent: 50),
                        _buildDpad(context),
                        const SizedBox(height: 60),

                        Text(
                          "Action Commands",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        const Divider(height: 20, thickness: 2, indent: 50, endIndent: 50),
                        _buildActionButtons(context),
                        const SizedBox(height: 40),

                        TextButton.icon(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          label: const Text("Restore Default Controls", style: TextStyle(color: Colors.grey)),
                          onPressed: () => _confirmReset(context),
                        ),
                      ],
                    ),
                  ),
                ),
    );

    if (widget.embedded) return bodyContent;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🤖 Path & Control Center", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: appBarColor, // Dark Green/Teal
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'Schedule Automation',
            onPressed: () => _openAutomationDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            tooltip: 'Manage Paths',
            onPressed: () => _openPlaybackDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Customize Buttons',
            onPressed: () => _openCustomizationDialog(context),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  // UI shown when playback is active
  Widget _buildPlaybackStatus() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            "PATH PLAYBACK ACTIVE",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Text(
            "Controls are disabled to prevent interruption.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text("STOP PLAYBACK NOW"),
            onPressed: () {
              setState(() {
                _isPlaybackActive = false; // Immediately stop the loop
              });
              _showSnackBar("🛑 Playback interrupted by user.");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          )
        ],
      ),
    );
  }

  // UI for the recording status and controls
  Widget _buildRecordingPanel() {
    Color statusColor = Colors.grey;
    String statusText = "Ready to Record";
    IconData statusIcon = Icons.radio_button_off;
    String countText = "";

    if (_recordingState == RecordingState.recording) {
      statusColor = Colors.red;
      statusText = "Recording Movement...";
      statusIcon = Icons.fiber_manual_record;
      countText = " (${_currentRecording.length} steps)";
    } else if (_recordingState == RecordingState.paused) {
      statusColor = Colors.orange;
      statusText = "Recording Paused";
      statusIcon = Icons.pause_circle_filled;
      countText = " (${_currentRecording.length} steps)";
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 28),
            const SizedBox(width: 8),
            Text(
              statusText + countText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            if (_recordingState == RecordingState.stopped)
              FilledButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text("Start Recording"),
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              ),
            
            if (_recordingState != RecordingState.stopped)
              FilledButton.icon(
                icon: Icon(_recordingState == RecordingState.recording ? Icons.pause : Icons.play_arrow),
                label: Text(_recordingState == RecordingState.recording ? "Pause" : "Resume"),
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
              ),
            
            if (_recordingState != RecordingState.stopped)
              FilledButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("End & Save Path"),
                onPressed: _endRecording,
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
          ],
        )
      ],
    );
  }

  // Finds a CommandButton by its command string, returns null if not found.
  CommandButton? _findCommand(String command, List<CommandButton> list) {
    for (var cmd in list) {
      if (cmd.command.toLowerCase() == command.toLowerCase()) {
        return cmd;
      }
    }
    return null;
  }

  // Builds the D-pad with dynamically loaded buttons
  Widget _buildDpad(BuildContext context) {
    final CommandButton? forward = _findCommand('forward', _customDpadCommands);
    final CommandButton? backward = _findCommand('backward', _customDpadCommands);
    final CommandButton? left = _findCommand('left', _customDpadCommands);
    final CommandButton? right = _findCommand('right', _customDpadCommands);
    final CommandButton? centerStop = _findCommand('stop', _customDpadCommands);

    return Column(
      children: [
        _buildCircularButton(forward, context),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircularButton(left, context),
            const SizedBox(width: 20),
            _buildCircularButton(centerStop, context, isCritical: true),
            const SizedBox(width: 20),
            _buildCircularButton(right, context),
          ],
        ),
        const SizedBox(height: 10),
        _buildCircularButton(backward, context),
      ],
    );
  }

  // Builds the other custom action buttons dynamically
  Widget _buildActionButtons(BuildContext context) {
    final List<CommandButton> actionButtons = _customActionCommands.toList();

    return Wrap(
      spacing: 15.0,
      runSpacing: 15.0,
      alignment: WrapAlignment.center,
      children: actionButtons.map((command) {
        return _buildStyledActionButton(command, context);
      }).toList(),
    );
  }

  // Reusable widget for circular D-pad buttons (Calls the recording wrapper)
  Widget _buildCircularButton(
      CommandButton? command, BuildContext context,
      {bool isCritical = false}) {
    if (command == null) return const SizedBox(width: 90, height: 90);

    return SizedBox(
      width: 90,
      height: 90,
      child: ElevatedButton(
        onPressed: () => _sendCommandAndRecord(command.command),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: command.color, // Use custom color
          foregroundColor: Colors.white,
          elevation: 5,
        ),
        child: _getButtonContent(command, size: 40),
      ),
    );
  }

  // Reusable widget for styled rectangular action buttons (Calls original sendCommand)
  Widget _buildStyledActionButton(
      CommandButton command, BuildContext context) {
    return ElevatedButton(
      onPressed: () => sendCommand(command.command),
      style: ElevatedButton.styleFrom(
        backgroundColor: command.color, // Use custom color
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getButtonContent(command, size: 24),
          if (command.label.isNotEmpty) const SizedBox(width: 8),
          Text(command.label.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Handles the content (Icon, Image, or Text) of a button
  Widget _getButtonContent(CommandButton command, {double size = 40}) {
    // Determine appropriate icon color based on button color luminance
    final Color contentColor = command.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    if (command.iconData != null) {
      return Icon(command.iconData, size: size, color: contentColor);
    } else if (command.imageUrl != null && command.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          command.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.broken_image, size: size * 0.75, color: contentColor),
        ),
      );
    } else {
      return Text(command.label.isNotEmpty ? command.label.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: contentColor));
    }
  }

  // --- Dialog Handlers ---

  void _openCustomizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _CustomizationDialog(
          dpadCommands: List.from(_customDpadCommands),
          actionCommands: List.from(_customActionCommands),
          onSave: (newDpadCommands, newActionCommands) {
            setState(() {
              _customDpadCommands = newDpadCommands;
              _customActionCommands = newActionCommands;
            });
            _saveCustomCommands();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _openPlaybackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PlaybackDialog(
        sequences: _savedSequences,
        onPlay: (sequence) {
          Navigator.pop(context);
          _playbackSequence(sequence);
        },
        onDelete: (sequence) {
          setState(() {
            _savedSequences.removeWhere((s) => s.name == sequence.name);
            _saveSequences();
          });
        },
        onUpdate: (updatedSequence) {
          setState(() {
            final index = _savedSequences.indexWhere((s) => s.name == updatedSequence.name);
            if (index != -1) {
              _savedSequences[index] = updatedSequence;
              _saveSequences();
            }
          });
        },
        getReversedSequence: _getReversedSequence,
      ),
    );
  }
  
  void _openAutomationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AutomationSchedulerDialog(
        sequences: _savedSequences,
      ),
    );
  }


  Future<void> _confirmReset(BuildContext context) async {
    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: const Text('Are you sure you want to restore all controls to their original default settings? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade100),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      setState(() {
        _setDefaults();
      });
      _showSnackBar("🔄 Controls successfully reset to default.");
    }
  }
}

// ====================================================================
// --- Path Preview Painter (Visualization) ---
// ====================================================================

class PathPreviewPainter extends CustomPainter {
  final List<SequenceCommand> commands;
  final double scaleFactor = 6.0; // Reduced scale for compact preview

  PathPreviewPainter(this.commands);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.shade500 // Use theme color for path
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final startPoint = Offset(size.width / 2, size.height / 2);
    double currentX = startPoint.dx;
    double currentY = startPoint.dy;

    final path = Path();
    path.moveTo(currentX, currentY);

    // Initial point (dot)
    canvas.drawCircle(startPoint, 3, Paint()..color = Colors.green.shade600..style = PaintingStyle.fill);


    for (final cmd in commands) {
      double deltaX = 0;
      double deltaY = 0;

      switch (cmd.command.toLowerCase()) {
        case 'forward':
          deltaY = -scaleFactor;
          break;
        case 'backward':
          deltaY = scaleFactor;
          break;
        case 'left':
          deltaX = -scaleFactor;
          break;
        case 'right':
          deltaX = scaleFactor;
          break;
        case 'stop':
          // Draw a small dot to indicate a stop/pause
          canvas.drawCircle(Offset(currentX, currentY), 1.5, Paint()..color = Colors.grey..style = PaintingStyle.fill);
          break;
      }
      
      // Update position
      currentX += deltaX;
      currentY += deltaY;

      // Ensure the path stays within bounds (for cleaner look)
      currentX = currentX.clamp(0, size.width);
      currentY = currentY.clamp(0, size.height);

      path.lineTo(currentX, currentY);
    }
    
    // Draw the path
    canvas.drawPath(path, paint);

    // Final point (red dot)
    canvas.drawCircle(Offset(currentX, currentY), 3, Paint()..color = Colors.red.shade600..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ====================================================================
// --- Playback Dialog Implementation ---
// ====================================================================
class _PlaybackDialog extends StatefulWidget {
  final List<MovementSequence> sequences;
  final Function(MovementSequence) onPlay;
  final Function(MovementSequence) onDelete;
  final Function(MovementSequence) onUpdate;
  final List<SequenceCommand> Function(List<SequenceCommand>) getReversedSequence;

  const _PlaybackDialog({
    required this.sequences,
    required this.onPlay,
    required this.onDelete,
    required this.onUpdate,
    required this.getReversedSequence,
  });

  @override
  State<_PlaybackDialog> createState() => __PlaybackDialogState();
}

class __PlaybackDialogState extends State<_PlaybackDialog> {
  late List<MovementSequence> _displaySequences;

  @override
  void initState() {
    super.initState();
    _displaySequences = List.from(widget.sequences);
  }
  
  void _openLoopSettings(MovementSequence originalSequence) {
    showDialog(
      context: context,
      builder: (context) => _LoopSettingsDialog(
        originalSequence: originalSequence,
        onSave: (updatedSequence) {
          widget.onUpdate(updatedSequence);
          setState(() {
            // Update the local list to reflect changes immediately
            final index = _displaySequences.indexWhere((s) => s.name == updatedSequence.name);
            if (index != -1) {
              _displaySequences[index] = updatedSequence;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Path Manager"),
      content: SizedBox(
        width: double.maxFinite,
        child: _displaySequences.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No paths saved yet. Start recording one!', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _displaySequences.length,
                itemBuilder: (context, index) {
                  final sequence = _displaySequences[index];
                  final reverseSteps = widget.getReversedSequence(sequence.commands).length;
                  
                  // ** MODIFIED Status Text for Prominence **
                  String statusText = "Steps: ${sequence.commands.length} | Reversible Path (${reverseSteps} steps)";
                  if (sequence.isLooped) {
                    statusText = sequence.isIndefinite 
                        ? "∞ Indefinite Loop (Path <-> Reverse)" 
                        : "🔁 Loops: ${sequence.loopCount} | Start: ${sequence.startReversed ? 'Reverse' : 'Normal'}";
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- START: Main Content Area (Replacing ListTile) ---
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Path Name and Icon
                              Row(
                                children: [
                                  const Icon(Icons.route, color: Colors.teal),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sequence.name, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              
                              // 2. STATUS TEXT (Now Prominently ABOVE Controls)
                              Text(
                                statusText, 
                                style: TextStyle(
                                  color: Colors.deepOrange.shade700, 
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // 3. CONTROL BUTTONS (Row)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.loop, color: sequence.isLooped ? Colors.purple.shade700 : Colors.grey),
                                    tooltip: 'Configure Looping',
                                    onPressed: () => _openLoopSettings(sequence),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                                    tooltip: 'Start Playback',
                                    onPressed: () => widget.onPlay(sequence),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete Path',
                                    onPressed: () {
                                        widget.onDelete(sequence);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // --- END: Main Content Area ---
                        
                        // --- START: Path Preview with text on top ---
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                          child: Stack(
                            clipBehavior: Clip.none, // Allows the badge to sit outside bounds
                            children: [
                              // The main box (Path Preview)
                              Container(
                                height: 70, // Reduced from 100 for compactness
                                // Add margin to offset the absolutely positioned chip below
                                margin: const EdgeInsets.only(top: 10), 
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.teal.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CustomPaint(
                                  painter: PathPreviewPainter(sequence.commands),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              
                              // The "Path Text" placed on top of the box
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.shade600, // Theme color
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                                  ),
                                  child: Text(
                                    "STEPS: ${sequence.commands.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // --- END: Path Preview with text on top ---
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ====================================================================
// --- Loop Settings Dialog (Inner Dialog) ---
// ====================================================================

class _LoopSettingsDialog extends StatefulWidget {
  final MovementSequence originalSequence;
  final Function(MovementSequence) onSave;

  const _LoopSettingsDialog({required this.originalSequence, required this.onSave});

  @override
  State<_LoopSettingsDialog> createState() => __LoopSettingsDialogState();
}

class __LoopSettingsDialogState extends State<_LoopSettingsDialog> {
  late bool _isLooped;
  late bool _isIndefinite;
  late int _loopCount;
  late bool _startReversed;
  
  @override
  void initState() {
    super.initState();
    _isLooped = widget.originalSequence.isLooped;
    _isIndefinite = widget.originalSequence.isIndefinite;
    _loopCount = widget.originalSequence.loopCount;
    _startReversed = widget.originalSequence.startReversed;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Loop Settings for ${widget.originalSequence.name}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Enable Loop (Path <-> Reverse)"),
              trailing: Switch(
                value: _isLooped,
                activeColor: Colors.deepOrange.shade600, // Theme color
                onChanged: (val) {
                  setState(() {
                    _isLooped = val;
                    if (!val) {
                      _isIndefinite = false; // Disable indefinite if looping is off
                    }
                  });
                },
              ),
            ),
            
            if (_isLooped) ...[
              const Divider(),
              ListTile(
                title: const Text("Indefinite Loop (∞)"),
                trailing: Switch(
                  value: _isIndefinite,
                  activeColor: Colors.deepOrange.shade600, // Theme color
                  onChanged: (val) {
                    setState(() {
                      _isIndefinite = val;
                    });
                  },
                ),
              ),
              
              const Divider(),
              
              if (!_isIndefinite)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text("Number of Loops (Pairs)"),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _loopCount,
                        items: [1, 2, 3, 5, 10]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _loopCount = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

              const Divider(),

              ListTile(
                title: const Text("Start with Reverse Path"),
                subtitle: Text(_startReversed ? "Reverse -> Normal -> Reverse..." : "Normal -> Reverse -> Normal..."),
                trailing: Switch(
                  value: _startReversed,
                  activeColor: Colors.deepOrange.shade600, // Theme color
                  onChanged: (val) {
                    setState(() {
                      _startReversed = val;
                    });
                  },
                ),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedSequence = MovementSequence(
              name: widget.originalSequence.name,
              commands: widget.originalSequence.commands,
              isLooped: _isLooped,
              isIndefinite: _isLooped ? _isIndefinite : false,
              loopCount: _isLooped && !_isIndefinite ? _loopCount : 1,
              startReversed: _isLooped ? _startReversed : false,
            );
            widget.onSave(updatedSequence);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

// ====================================================================
// --- Automation Scheduler Dialog (Simulated) ---
// ====================================================================

class _AutomationSchedulerDialog extends StatefulWidget {
  final List<MovementSequence> sequences;

  const _AutomationSchedulerDialog({required this.sequences});

  @override
  State<_AutomationSchedulerDialog> createState() => __AutomationSchedulerDialogState();
}

class __AutomationSchedulerDialogState extends State<_AutomationSchedulerDialog> {
  MovementSequence? _selectedSequence;
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  @override
  void initState() {
    super.initState();
    if (widget.sequences.isNotEmpty) {
      _selectedSequence = widget.sequences.first;
    }
  }

  void _schedule() {
    if (_selectedSequence == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a path to schedule.")),
      );
      return;
    }
    
    // This part is simulated, as actual background scheduling is not possible
    // in this single-file Flutter environment.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Scheduled: '${_selectedSequence!.name}' to run every day at ${_selectedTime.format(context)}."),
        backgroundColor: Colors.teal,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Schedule Automation"),
      content: widget.sequences.isEmpty 
        ? const Text("You must create and save a movement path before scheduling automation.")
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Path to Run:"),
              DropdownButtonFormField<MovementSequence>(
                value: _selectedSequence,
                items: widget.sequences
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSequence = val;
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Text("Run Time:"),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 18)),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        if (widget.sequences.isNotEmpty)
          ElevatedButton(
            onPressed: _schedule,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
            child: const Text("Set Schedule"),
          ),
      ],
    );
  }
}


// ====================================================================
// --- Customization Dialog Implementation ---
// ====================================================================
class _CustomizationDialog extends StatefulWidget {
  final List<CommandButton> dpadCommands;
  final List<CommandButton> actionCommands;
  final Function(List<CommandButton>, List<CommandButton>) onSave;

  const _CustomizationDialog({
    required this.dpadCommands,
    required this.actionCommands,
    required this.onSave,
  });

  @override
  State<_CustomizationDialog> createState() => __CustomizationDialogState();
}

class __CustomizationDialogState extends State<_CustomizationDialog> {
  late List<CommandButton> _tempDpadCommands;
  late List<CommandButton> _tempActionCommands;

  @override
  void initState() {
    super.initState();
    // Clone command lists for temporary editing
    _tempDpadCommands = widget.dpadCommands.map((c) => CommandButton.fromJson(c.toJson())).toList();
    _tempActionCommands = widget.actionCommands.map((c) => CommandButton.fromJson(c.toJson())).toList();
  }

  void _editButton(
      CommandButton? button, List<CommandButton> listToModify) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ButtonEditForm(
          button: button,
          onSave: (newButton) {
            setState(() {
              if (button == null) {
                // Add new button
                listToModify.add(newButton);
              } else {
                // Edit existing button (find and replace)
                final index = listToModify.indexWhere((cmd) => cmd.command == button.command);
                if (index != -1) {
                  listToModify[index] = newButton;
                }
              }
            });
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Customize Robot Controls"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Directional Buttons (D-pad) - Tap to Edit",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildCommandList(_tempDpadCommands),
            const SizedBox(height: 20),

            Text(
              "Action Buttons (Custom) - Edit or Delete",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildCommandList(_tempActionCommands, canDelete: true),

            if (_tempActionCommands.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('No custom buttons. Click "Add New Action" to create one.'),
              ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add New Action"),
                onPressed: () => _editButton(null, _tempActionCommands),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Save Changes'),
          onPressed: () => widget.onSave(_tempDpadCommands, _tempActionCommands),
        ),
      ],
    );
  }

  Widget _buildCommandList(List<CommandButton> commands, {bool canDelete = false}) {
    return Column(
      children: commands.map((command) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: _getButtonContent(command, size: 24),
            title: Text(command.label.isNotEmpty ? command.label : 'No Label'),
            subtitle: Text("Command: ${command.command}"),
            onTap: () => _editButton(command, commands),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canDelete) 
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        commands.remove(command);
                      });
                    },
                  ),
                if (!canDelete)
                  const Icon(Icons.edit, color: Colors.teal),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _getButtonContent(CommandButton command, {double size = 40}) {
    // Determine appropriate icon color based on button color luminance
    final Color contentColor = command.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    if (command.iconData != null) {
      return Icon(command.iconData, size: size, color: contentColor);
    } else if (command.imageUrl != null && command.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          command.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.broken_image, size: size * 0.75, color: Colors.red),
        ),
      );
    } else {
      return Text(
          command.label.isNotEmpty
              ? command.label.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: contentColor));
    }
  }
}

// ====================================================================
// --- Button Edit Form (Inner Dialog) ---
// ====================================================================
class _ButtonEditForm extends StatefulWidget {
  final CommandButton? button;
  final Function(CommandButton) onSave;

  const _ButtonEditForm({this.button, required this.onSave});

  @override
  State<_ButtonEditForm> createState() => __ButtonEditFormState();
}

class __ButtonEditFormState extends State<_ButtonEditForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _commandController;
  late TextEditingController _iconKeyController;
  late TextEditingController _imageController;
  late TextEditingController _colorController; // New controller for hex color

  // Color palette for easy selection
  static const List<String> _colorPalette = [
    '#00BCD4', // Cyan (Teal theme color)
    '#FF5722', // Deep Orange (Current theme highlight)
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
    '#FFC107', // Amber
    '#F44336', // Red
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];


  final Map<String, IconData> _suggestedIcons = {
    'lightbulb': SupportedIcons.iconMap['lightbulb']!,
    'assistant_photo': SupportedIcons.iconMap['code']!,
    'home': SupportedIcons.iconMap['home']!,
    'camera': SupportedIcons.iconMap['play_circle']!,
  };

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.button?.label ?? '');
    _commandController =
        TextEditingController(text: widget.button?.command ?? '');
    _iconKeyController =
        TextEditingController(text: widget.button?.iconKey ?? '');
    _imageController =
        TextEditingController(text: widget.button?.imageUrl ?? '');
    
    // Initialize color controller with existing color or a theme default
    String initialColor = widget.button?.buttonColorHex ?? '#FF5722'; // Deep Orange default
    _colorController = TextEditingController(text: initialColor);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    _iconKeyController.dispose();
    _imageController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final newButton = CommandButton(
        label: _labelController.text,
        command: _commandController.text,
        iconKey:
            _iconKeyController.text.isNotEmpty ? _iconKeyController.text : null,
        imageUrl:
            _imageController.text.isNotEmpty ? _imageController.text : null,
        buttonColorHex: _colorController.text.toUpperCase(),
      );
      widget.onSave(newButton);
    }
  }

  void _selectIcon(String iconKey) {
    setState(() {
      _iconKeyController.text = iconKey;
      _imageController.clear(); // Clear image if an icon is selected
    });
  }
  
  // New method to handle color selection from the palette
  void _selectColor(String hex) {
    setState(() {
      _colorController.text = hex;
    });
  }

  // Helper to safely get the current color from the hex controller
  Color _getCurrentColor() {
    String hex = _colorController.text.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconData? currentIcon = SupportedIcons.getIcon(_iconKeyController.text);
    final Color currentColor = _getCurrentColor();
    // Determine appropriate icon color based on button color luminance
    final Color contentColor = currentColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;


    return AlertDialog(
      title: Text(widget.button == null ? "Add New Button" : "Edit Button"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                    labelText: "Button Label (Text)",
                    hintText: "e.g., 'Go Home'"),
              ),
              TextFormField(
                controller: _commandController,
                decoration: const InputDecoration(
                    labelText: "Command String (to ESP8266)",
                    hintText: "e.g., 'home_sequence'"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Command string cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // --- Color Picker Section ---
              const Text('Button Color', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: "Hex Color Code (e.g., #FF5722)",
                  hintText: "#FF5722",
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12)
                      ),
                    ),
                  ),
                ),
                onChanged: (value) => setState(() {}),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final hexRegex = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
                    if (!hexRegex.hasMatch(value)) {
                      return 'Enter a valid hex code (e.g., #FF0000).';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),
              
              // --- Color Palette Selector ---
              const Text('Select from Palette:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                alignment: WrapAlignment.center,
                children: _colorPalette.map((hex) {
                  Color color;
                  try {
                    String cleanHex = hex.replaceAll('#', '');
                    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
                    color = Color(int.parse(cleanHex, radix: 16));
                  } catch (_) {
                    color = Colors.black;
                  }
                  
                  // Check if this color is currently selected (for border highlight)
                  final bool isSelected = _colorController.text.toUpperCase() == hex.toUpperCase();

                  return GestureDetector(
                    onTap: () => _selectColor(hex),
                    child: Tooltip(
                      message: hex,
                      child: Container(
                        width: 36, // Slightly larger touch target
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),

              // --- Icon Selection Section ---
              const Text('Visual Design (Choose Icon or Image URL)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _iconKeyController,
                decoration: InputDecoration(
                  labelText: "Material Icon Key",
                  hintText: "e.g., 'home' or 'camera'",
                  suffixIcon: _iconKeyController.text.isNotEmpty
                      ? Icon(
                          currentIcon ?? Icons.help,
                          color: contentColor,
                          )
                      : null,
                ),
                readOnly: true,
                onTap: () async {
                  _showIconPicker(context);
                },
              ),

              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: _suggestedIcons.entries
                    .map((entry) => ActionChip(
                          avatar: Icon(entry.value, size: 18, color: Colors.teal.shade700),
                          label: Text(entry.key),
                          onPressed: () => _selectIcon(SupportedIcons.getKey(entry.value)!),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 15),

              // --- Image URL Section ---
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                    labelText: "Custom Image URL (For Photo from Device, use a hosting service)",
                    hintText: "e.g., https://example.com/robot.png"),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    _iconKeyController.clear();
                  }
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),

              if (_imageController.text.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _imageController.text,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Text("Image failed to load.", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          onPressed: _saveForm,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _showIconPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return GridView.count(
          crossAxisCount: 6,
          padding: const EdgeInsets.all(10),
          children: SupportedIcons.iconMap.entries.map((entry) {
            return IconButton(
              icon: Icon(entry.value, size: 36),
              color: Colors.teal.shade700,
              onPressed: () {
                _selectIcon(entry.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

// ====================================================================
// --- Extension to find the first element or return null ---
// ====================================================================
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
