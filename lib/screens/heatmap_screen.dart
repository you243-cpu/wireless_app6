// Add the new 3D toggle button next to the date range control
Row(
  children: [
    ElevatedButton.icon(
      onPressed: () {
        // Existing action for date range control
      },
      icon: Icon(Icons.calendar_today),
      label: Text('Date Range'),
    ),
    SizedBox(width: 8), // Space between buttons
    ElevatedButton(
      onPressed: () {
        // Action for 3D toggle
      },
      child: Text('3D'),
    ),
  ],
),