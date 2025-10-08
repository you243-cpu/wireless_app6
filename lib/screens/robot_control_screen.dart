import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async'; // For Future.delayed during playback

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
}

// Stores an entire named sequence of commands.
class MovementSequence {
  final String name;
  final List<SequenceCommand> commands;

  MovementSequence({required this.name, required this.commands});

  Map<String, dynamic> toJson() => {
        'name': name,
        'commands': commands.map((c) => c.toJson()).toList(),
      };

  factory MovementSequence.fromJson(Map<String, dynamic> json) => MovementSequence(
        name: json['name'] as String,
        commands: (json['commands'] as List)
            .map((item) => SequenceCommand.fromJson(item))
            .toList(),
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
    'lightbulb_outline': Icons.lightbulb_outline,
    'assistant_photo': Icons.assistant_photo,
    'code': Icons.code,
    'home': Icons.home,
    'power': Icons.power_settings_new,
    'sensors': Icons.sensors,
    'camera': Icons.camera_alt,
    'build': Icons.build,
    'play_circle': Icons.play_circle,
    'settings_power': Icons.settings_power,
    'radio': Icons.radio_button_checked,
  };

  // Helper to get the actual IconData using the global map
  static IconData? getIcon(String key) {
    return iconMap[key];
  }

  // Helper to get the string key from an IconData object
  static String? getKey(IconData icon) {
    // Note: This needs to iterate through all entries to find a match, less efficient but necessary.
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

  CommandButton({
    required this.label,
    required this.command,
    this.iconKey,
    this.imageUrl,
  });

  // Convert a CommandButton to a JSON map
  Map<String, dynamic> toJson() => {
        'label': label,
        'command': command,
        'iconKey': iconKey,
        'imageUrl': imageUrl,
      };

  // Create a CommandButton from a JSON map
  factory CommandButton.fromJson(Map<String, dynamic> json) => CommandButton(
        label: json['label'] as String,
        command: json['command'] as String,
        iconKey: json['iconKey'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  // Helper to get the actual IconData from the stored string key
  IconData? get iconData => iconKey != null ? SupportedIcons.getIcon(iconKey!) : null;
}

// ====================================================================
// --- Main Control Screen (Exported for Dashboard) ---
// ====================================================================
enum RecordingState { stopped, recording, paused }

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  static const String _prefsKey = 'customRobotCommands';
  static const String _sequencePrefsKey = 'robotMovementSequences'; // Key for sequences
  final String espIP = "192.168.4.1"; // ESP8266 IP (Same as Dashboard)

  // Default D-pad commands
  final List<CommandButton> _defaultDpadCommands = [
    CommandButton(
        label: 'Forward', command: 'forward', iconKey: 'arrow_upward'),
    CommandButton(
        label: 'Backward', command: 'backward', iconKey: 'arrow_downward'),
    CommandButton(label: 'Left', command: 'left', iconKey: 'arrow_back'),
    CommandButton(label: 'Right', command: 'right', iconKey: 'arrow_forward'),
    CommandButton(label: 'STOP', command: 'stop', iconKey: 'pause'),
  ];

  // Default Action commands
  final List<CommandButton> _defaultActionCommands = [
    CommandButton(label: 'Lights On', command: 'lights_on', iconKey: 'lightbulb'),
    CommandButton(label: 'EMERGENCY STOP', command: 'emergency_stop', iconKey: 'warning'),
  ];

  List<CommandButton> _customDpadCommands = [];
  List<CommandButton> _customActionCommands = [];
  List<MovementSequence> _savedSequences = [];
  bool _isLoading = true;

  // --- Recording State Variables ---
  RecordingState _recordingState = RecordingState.stopped;
  List<SequenceCommand> _currentRecording = [];
  DateTime? _lastCommandTime;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- Persistence Handlers ---

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
    _customDpadCommands = List.from(_defaultDpadCommands);
    _customActionCommands = List.from(_defaultActionCommands);
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
        // Quietly fail for sequence loading errors if needed.
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
            "✅ Command '$command' sent. Response: ${response.body.isNotEmpty ? response.body : 'OK'}";
      } else {
        message =
            "❌ Failed to send command. Status: ${response.statusCode}. Response: ${response.body}";
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

    if (_currentRecording.length <= 1) {
      _showSnackBar("Recording ended. Sequence too short to save (min 2 steps required).");
      _currentRecording = [];
      return;
    }

    _showSaveSequenceDialog(context);
  }

  Future<void> _showSaveSequenceDialog(BuildContext context) async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Movement Sequence'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Sequence Name'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- Playback Logic ---

  Future<void> _playbackSequence(MovementSequence sequence) async {
    _showSnackBar("▶️ Starting playback for '${sequence.name}'...");
    
    for (int i = 0; i < sequence.commands.length; i++) {
      final cmd = sequence.commands[i];
      
      if (cmd.delayMs > 0) {
        await Future.delayed(Duration(milliseconds: cmd.delayMs));
      }

      await sendCommand(cmd.command);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnackBar("Executing: ${cmd.command}");
      }
    }
    _showSnackBar("✅ Playback for '${sequence.name}' finished.");
  }


  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🤖 Custom Robot Control", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          // Button for Playback Dialog
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            tooltip: 'Play Saved Sequence',
            onPressed: () => _openPlaybackDialog(context),
          ),
          // Button for Customization Dialog
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Customize Buttons',
            onPressed: () => _openCustomizationDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- Recording Status Section ---
                    _buildRecordingPanel(),
                    const SizedBox(height: 30),

                    // --- D-pad Control Section ---
                    Text(
                      "Directional Controls",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const Divider(height: 20, thickness: 2, indent: 50, endIndent: 50),
                    _buildDpad(context),
                    const SizedBox(height: 60),

                    // --- Action Buttons Section ---
                    Text(
                      "Action Commands",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const Divider(height: 20, thickness: 2, indent: 50, endIndent: 50),
                    _buildActionButtons(context),
                    const SizedBox(height: 40),

                    // --- Reset Button ---
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
            // START RECORDING button
            if (_recordingState == RecordingState.stopped)
              FilledButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text("Start Recording"),
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              ),
            
            // PAUSE / RESUME button
            if (_recordingState != RecordingState.stopped)
              FilledButton.icon(
                icon: Icon(_recordingState == RecordingState.recording ? Icons.pause : Icons.play_arrow),
                label: Text(_recordingState == RecordingState.recording ? "Pause" : "Resume"),
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
              ),
            
            // END RECORDING button
            if (_recordingState != RecordingState.stopped)
              FilledButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("End Recording"),
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
        // Forward button
        _buildCircularButton(forward, context),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left button
            _buildCircularButton(left, context),
            const SizedBox(width: 20),
            // Center Stop button
            _buildCircularButton(centerStop, context, isCritical: true),
            const SizedBox(width: 20),
            // Right button
            _buildCircularButton(right, context),
          ],
        ),
        const SizedBox(height: 10),
        // Backward button
        _buildCircularButton(backward, context),
      ],
    );
  }

  // Builds the other custom action buttons dynamically
  Widget _buildActionButtons(BuildContext context) {
    final List<CommandButton> actionButtons = _customActionCommands.toList(); // All actions

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
    if (command == null) return const SizedBox(width: 80, height: 80);

    return SizedBox(
      width: 90,
      height: 90,
      child: ElevatedButton(
        // Use the recording wrapper for directional and central stop buttons
        onPressed: () => _sendCommandAndRecord(command.command),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: isCritical ? Colors.red.shade700 : Colors.blue.shade700,
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
    final bool isEmergency = command.command.toLowerCase().contains('emergency');
    return ElevatedButton(
      // Non-movement commands just call the original sendCommand
      onPressed: () => sendCommand(command.command),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEmergency ? Colors.red.shade900 : Colors.teal,
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
    if (command.iconData != null) {
      return Icon(command.iconData, size: size);
    } else if (command.imageUrl != null && command.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          command.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.broken_image, size: size * 0.75),
        ),
      );
    } else {
      return Text(command.label.isNotEmpty ? command.label.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold));
    }
  }

  // --- Customization Dialogs ---

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
          Navigator.pop(context); // Close dialog
          _playbackSequence(sequence);
        },
        onDelete: (sequence) {
          setState(() {
            _savedSequences.removeWhere((s) => s.name == sequence.name);
            _saveSequences();
          });
        },
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
// --- Playback Dialog Implementation ---
// ====================================================================
class _PlaybackDialog extends StatefulWidget {
  final List<MovementSequence> sequences;
  final Function(MovementSequence) onPlay;
  final Function(MovementSequence) onDelete;

  const _PlaybackDialog({
    required this.sequences,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  State<_PlaybackDialog> createState() => __PlaybackDialogState();
}

class __PlaybackDialogState extends State<_PlaybackDialog> {
  late List<MovementSequence> _displaySequences;

  @override
  void initState() {
    super.initState();
    // Use a temporary list derived from the widget's list for display
    _displaySequences = List.from(widget.sequences);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Recorded Movement Sequences"),
      content: SizedBox(
        width: double.maxFinite,
        child: _displaySequences.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No movement sequences saved yet. Start recording one!', 
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    elevation: 2,
                    child: ListTile(
                      tileColor: Colors.blueGrey.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: const Icon(Icons.movie, color: Colors.blue),
                      title: Text(sequence.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${sequence.commands.length} steps | Duration: ${(sequence.commands.fold(0, (sum, cmd) => sum + cmd.delayMs) / 1000).toStringAsFixed(1)}s"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            tooltip: 'Start Playback',
                            onPressed: () => widget.onPlay(sequence),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Sequence',
                            onPressed: () {
                                // Since we pass the state update to the parent, we don't need a local setState for deletion here.
                                // The parent will rebuild the widget list.
                                widget.onDelete(sequence);
                            },
                          ),
                        ],
                      ),
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
    _tempDpadCommands = List.from(widget.dpadCommands);
    _tempActionCommands = List.from(widget.actionCommands);
  }

  // Shows the form for adding/editing a button
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
                // Edit existing button
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
            // --- D-pad Customization ---
            Text(
              "Directional Buttons (D-pad) - Tap to Edit",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildCommandList(_tempDpadCommands),
            const SizedBox(height: 20),

            // --- Action Buttons Customization ---
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

  // Reusable widget to display and manage a list of CommandButtons
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
                if (canDelete) // Only allow deletion for custom action buttons
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        commands.remove(command);
                      });
                    },
                  ),
                if (!canDelete) // For D-pad, just show an edit icon
                  const Icon(Icons.edit, color: Colors.blue),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Handles the content (Icon, Image, or Text) for the customization list
  Widget _getButtonContent(CommandButton command, {double size = 40}) {
    if (command.iconData != null) {
      return Icon(command.iconData, size: size);
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
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold));
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

  // A few common icons for easy selection (NOW USING KEYS)
  final Map<String, IconData> _suggestedIcons = {
    'lightbulb': SupportedIcons.iconMap['lightbulb']!,
    'assistant_photo': SupportedIcons.iconMap['assistant_photo']!,
    'code': SupportedIcons.iconMap['code']!,
    'home': SupportedIcons.iconMap['home']!,
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
        TextController(text: widget.button?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    _iconKeyController.dispose();
    _imageController.dispose();
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
      );
      widget.onSave(newButton);
    }
  }

  // Select icon by its string key
  void _selectIcon(String iconKey) {
    setState(() {
      _iconKeyController.text = iconKey;
      _imageController.clear(); // Clear image if an icon is selected
    });
  }

  @override
  Widget build(BuildContext context) {
    final IconData? currentIcon = SupportedIcons.getIcon(_iconKeyController.text);
    
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
                          color: Colors.blue)
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
                          avatar: Icon(entry.value, size: 18),
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
                    labelText: "Custom Image URL",
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

  // Icon Picker uses the SupportedIcons map
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
// (Needed because firstWhereOrNull is not in core Dart)
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
