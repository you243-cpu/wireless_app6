import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For encoding/decoding JSON

// --- Model for a Custom Robot Command Button ---
class CommandButton {
  final String label;
  final String command;
  final String? iconCodePoint; // Stored as a string for SharedPreferences
  final String? imageUrl;

  CommandButton({
    required this.label,
    required this.command,
    this.iconCodePoint,
    this.imageUrl,
  });

  // Convert a CommandButton to a JSON map
  Map<String, dynamic> toJson() => {
        'label': label,
        'command': command,
        'iconCodePoint': iconCodePoint,
        'imageUrl': imageUrl,
      };

  // Create a CommandButton from a JSON map
  factory CommandButton.fromJson(Map<String, dynamic> json) => CommandButton(
        label: json['label'] as String,
        command: json['command'] as String,
        iconCodePoint: json['iconCodePoint'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  // Helper to get the actual IconData from the stored string
  IconData? get iconData => iconCodePoint != null
      ? IconData(
          int.parse(iconCodePoint!),
          fontFamily: 'MaterialIcons',
        )
      : null;
}

// --- Main Control Screen ---
class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  static const String _prefsKey = 'customRobotCommands';
  final String espIP = "192.168.4.1"; // ESP8266 IP

  // Default D-pad commands (used for initial load and reset)
  final List<CommandButton> _defaultDpadCommands = [
    CommandButton(
        label: 'Forward',
        command: 'forward',
        iconCodePoint: Icons.arrow_upward.codePoint.toString()),
    CommandButton(
        label: 'Backward',
        command: 'backward',
        iconCodePoint: Icons.arrow_downward.codePoint.toString()),
    CommandButton(
        label: 'Left',
        command: 'left',
        iconCodePoint: Icons.arrow_back.codePoint.toString()),
    CommandButton(
        label: 'Right',
        command: 'right',
        iconCodePoint: Icons.arrow_forward.codePoint.toString()),
    CommandButton(
        label: 'STOP',
        command: 'stop',
        iconCodePoint: Icons.pause.codePoint.toString()),
  ];

  // Default Action commands (used for initial load and reset)
  final List<CommandButton> _defaultActionCommands = [
    CommandButton(
        label: 'STOP',
        command: 'stop',
        iconCodePoint: Icons.stop.codePoint.toString()),
    CommandButton(
        label: 'EMERGENCY STOP',
        command: 'emergency_stop',
        iconCodePoint: Icons.warning.codePoint.toString()),
  ];

  List<CommandButton> _customDpadCommands = [];
  List<CommandButton> _customActionCommands = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomCommands();
  }

  // --- Persistence Handlers ---

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
        // If decoding fails, fall back to defaults
        _setDefaults();
        _showSnackBar("⚠️ Failed to load custom settings. Restored to defaults.");
      }
    } else {
      // No saved data, set to default
      _setDefaults();
    }

    setState(() {
      _isLoading = false;
    });
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
    _saveCustomCommands(); // Save the defaults so they persist
  }

  // --- Communication & Feedback ---

  // Helper to send commands to the ESP8266 and handle the response
  Future<void> sendCommand(String command) async {
    // Basic validation to prevent empty commands
    if (command.isEmpty) {
      _showSnackBar("❌ Command string is empty.");
      return;
    }

    try {
      // The ESP8266 IP and command structure are kept the same
      final url = Uri.parse("http://$espIP/command?action=$command");
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      String message;
      if (response.statusCode == 200) {
        message =
            "✅ Command '${command}' sent. Response: ${response.body.isNotEmpty ? response.body : 'OK'}";
      } else {
        message =
            "❌ Failed to send command. Status: ${response.statusCode}. Response: ${response.body}";
      }

      _showSnackBar(message);
    } catch (e) {
      _showSnackBar("❌ Error sending command to $espIP: $e");
    }
  }

  // Helper to show a SnackBar with feedback
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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

  // Builds the D-pad with dynamically loaded buttons
  Widget _buildDpad(BuildContext context) {
    // Find the buttons for forward, backward, left, right, and center stop
    final CommandButton? forward = _customDpadCommands.firstWhereOrNull(
        (cmd) => cmd.command.toLowerCase() == 'forward');
    final CommandButton? backward = _customDpadCommands.firstWhereOrNull(
        (cmd) => cmd.command.toLowerCase() == 'backward');
    final CommandButton? left = _customDpadCommands.firstWhereOrNull(
        (cmd) => cmd.command.toLowerCase() == 'left');
    final CommandButton? right = _customDpadCommands.firstWhereOrNull(
        (cmd) => cmd.command.toLowerCase() == 'right');
    final CommandButton? centerStop = _customDpadCommands.firstWhereOrNull(
        (cmd) => cmd.command.toLowerCase() == 'stop' && cmd.label.toLowerCase() == 'stop');

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
    // Filter out the dpad commands already used above
    final List<CommandButton> actionButtons = _customActionCommands
        .where((cmd) => !_defaultDpadCommands.any((d) => d.command == cmd.command))
        .toList();

    return Wrap(
      spacing: 15.0,
      runSpacing: 15.0,
      alignment: WrapAlignment.center,
      children: actionButtons.map((command) {
        return _buildStyledActionButton(command, context);
      }).toList(),
    );
  }

  // Reusable widget for circular D-pad buttons
  Widget _buildCircularButton(
      CommandButton? command, BuildContext context,
      {bool isCritical = false}) {
    if (command == null) return const SizedBox(width: 80, height: 80); // Placeholder

    return SizedBox(
      width: 90,
      height: 90,
      child: ElevatedButton(
        onPressed: () => sendCommand(command.command),
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

  // Reusable widget for styled rectangular action buttons
  Widget _buildStyledActionButton(
      CommandButton command, BuildContext context) {
    final bool isEmergency = command.command.toLowerCase().contains('emergency');
    return ElevatedButton(
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
      // NOTE: Using a NetworkImage here requires the image URL to be accessible!
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
      return Text(command.label.substring(0, 1).toUpperCase(),
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold));
    }
  }

  // --- Customization Dialogs ---

  void _openCustomizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Use a temporary stateful widget for the dialog to allow button addition/removal
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

// --- Extension to find the first element or return null ---
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


// --- Customization Dialog Implementation ---
// (Needs to be a separate StateFulWidget to manage temporary changes)
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
                final index = listToModify.indexOf(button);
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
              "Directional Buttons (D-pad)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildCommandList(_tempDpadCommands),
            const SizedBox(height: 20),

            // --- Action Buttons Customization ---
            Text(
              "Action Buttons (Custom)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildCommandList(_tempActionCommands, canAdd: true),

            if (_tempActionCommands.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('No custom buttons. Click "Add New Action" to create one.'),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add New Action"),
              onPressed: () => _editButton(null, _tempActionCommands),
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
  Widget _buildCommandList(List<CommandButton> commands, {bool canAdd = false}) {
    return Column(
      children: commands.map((command) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: _getButtonContent(command, size: 24),
            title: Text(command.label.isNotEmpty ? command.label : 'No Label'),
            subtitle: Text("Command: ${command.command}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editButton(command, commands),
                ),
                if (canAdd) // Only allow deletion for custom action buttons
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        commands.remove(command);
                      });
                    },
                  ),
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

// --- Button Edit Form (Inner Dialog) ---
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
  late TextEditingController _iconController;
  late TextEditingController _imageController;

  // A few common icons for easy selection
  final Map<String, IconData> _suggestedIcons = {
    'Light On': Icons.lightbulb,
    'Light Off': Icons.lightbulb_outline,
    'Auto': Icons.assistant_photo,
    'Run Script': Icons.code,
  };

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.button?.label ?? '');
    _commandController =
        TextEditingController(text: widget.button?.command ?? '');
    _iconController =
        TextEditingController(text: widget.button?.iconCodePoint ?? '');
    _imageController =
        TextEditingController(text: widget.button?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    _iconController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final newButton = CommandButton(
        label: _labelController.text,
        command: _commandController.text,
        iconCodePoint:
            _iconController.text.isNotEmpty ? _iconController.text : null,
        imageUrl:
            _imageController.text.isNotEmpty ? _imageController.text : null,
      );
      widget.onSave(newButton);
    }
  }

  void _selectIcon(IconData iconData) {
    setState(() {
      _iconController.text = iconData.codePoint.toString();
      _imageController.clear(); // Clear image if an icon is selected
    });
  }

  @override
  Widget build(BuildContext context) {
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
                controller: _iconController,
                decoration: InputDecoration(
                  labelText: "Material Icon CodePoint",
                  hintText: "e.g., 59473 (for Icons.home)",
                  suffixIcon: _iconController.text.isNotEmpty
                      ? Icon(
                          IconData(int.tryParse(_iconController.text) ?? 0,
                              fontFamily: 'MaterialIcons'),
                          color: Colors.blue)
                      : null,
                ),
                readOnly: true,
                onTap: () async {
                  // In a real app, you'd use an icon picker. Here, we'll show a sample.
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
                          onPressed: () => _selectIcon(entry.value),
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
                    _iconController.clear(); // Clear icon if an image is used
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

  // Simplified Icon Picker for demonstration
  void _showIconPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return GridView.count(
          crossAxisCount: 6,
          padding: const EdgeInsets.all(10),
          children: [
            Icons.home,
            Icons.power_settings_new,
            Icons.sensors,
            Icons.camera_alt,
            Icons.build,
            Icons.lightbulb,
          ].map((icon) {
            return IconButton(
              icon: Icon(icon, size: 36),
              onPressed: () {
                _selectIcon(icon);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
