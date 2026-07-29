import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DatePlannerDialog extends StatefulWidget {
  final Map<String, dynamic>? initialDatePlan;
  const DatePlannerDialog({super.key, this.initialDatePlan});

  @override
  State<DatePlannerDialog> createState() => _DatePlannerDialogState();
}

class _DatePlannerDialogState extends State<DatePlannerDialog> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialDatePlan != null) {
      _titleController.text = widget.initialDatePlan!['title'] ?? '';
      _locationController.text = widget.initialDatePlan!['location'] ?? '';
      try {
        _selectedDateTime = DateTime.parse(widget.initialDatePlan!['date']).toLocal();
      } catch (_) {}
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C1820),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: Colors.white,
                onSurface: Color(0xFF2C1820),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final location = _locationController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title for the meet-up.';
      });
      return;
    }

    if (_selectedDateTime == null) {
      setState(() {
        _errorMessage = 'Please select a date and time.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.initialDatePlan != null) {
        final int planId = widget.initialDatePlan!['id'];
        await ApiService.instance.updateDatePlan(planId, title, _selectedDateTime!, location.isEmpty ? null : location);
      } else {
        await ApiService.instance.proposeDatePlan(title, _selectedDateTime!, location.isEmpty ? null : location);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = widget.initialDatePlan != null
            ? 'Failed to update meet-up plan. Please try again.'
            : 'Failed to propose meet-up plan. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxDialogHeight = screenHeight - keyboardHeight - 100;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.initialDatePlan != null ? 'Edit Meet-up Details' : 'Plan Meet-up Tonight',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C1820),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Color(0xFF8E717D)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Title Field
                Text(
                  'Meet-up Title',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Candlelit Dinner',
                    hintStyle: TextStyle(color: Colors.black26),
                    filled: true,
                    fillColor: Color(0xFFFFECEF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
  
                // Location Field
                Text(
                  'Location (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Bella Italia Restaurant',
                    hintStyle: TextStyle(color: Colors.black26),
                    filled: true,
                    fillColor: Color(0xFFFFECEF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
  
                // DateTime Picker
                Text(
                  'Date & Time',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
                ),
                SizedBox(height: 6),
                InkWell(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFECEF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDateTime != null
                                ? DateFormat('EEEE, MMM d, y • h:mm a').format(_selectedDateTime!)
                                : 'Select Date & Time',
                            style: TextStyle(
                              color: _selectedDateTime != null ? Color(0xFF2C1820) : Colors.black26,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
  
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                ],
  
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.initialDatePlan != null ? 'Update Meet-up Details' : 'Propose Meet-up',
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.favorite_border_rounded, size: 16),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
