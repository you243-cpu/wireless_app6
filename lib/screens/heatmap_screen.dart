                   Row(
                     children: [
                       Expanded(
                         child: ElevatedButton.icon(
                           onPressed: _selectDateRange,
                           icon: const Icon(Icons.date_range),
                           label: Text(
                             startTime != null && endTime != null
                                 ? (_selectedRunIndex >= 0
                                     ? 'Run ${_selectedRunIndex + 1}: ${startTime!.toString().split('.')[0]} - ${endTime!.toString().split('.')[0]}'
                                     : 'Viewing Data from ${startTime!.toString().split('.')[0]} to ${endTime!.toString().split('.')[0]}')
                                 : 'Select Date & Time Range',
                             style: const TextStyle(fontSize: 12),
                           ),
                           style: ElevatedButton.styleFrom(
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(20),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       ElevatedButton.icon(
                         onPressed: _toggleView,
                         icon: const Icon(Icons.view_in_ar),
                         label: Text(is3DView ? '2D View' : '3D View',
                           style: const TextStyle(fontSize: 12),
                         ),
                         style: ElevatedButton.styleFrom(
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(20),
                           ),
                         ),
                       ),
                     ],
                   ),
