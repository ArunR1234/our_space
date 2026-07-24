import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DatePlannerDialog extends StatefulWidget {
  const DatePlannerDialog({super.key});

  @override
  State<DatePlannerDialog> createState() => _DatePlannerDialogState();
}

class _DatePlannerDialogState extends State<DatePlannerDialog> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFB5003F),
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
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFB5003F),
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
        _errorMessage = 'Please enter a title for the date.';
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
      await ApiService.instance.proposeDatePlan(title, _selectedDateTime!, location.isEmpty ? null : location);
      if (mounted) {
        Navigator.pop(context, true); // Returns true to trigger dashboard refresh
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to propose date plan. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: const Color(0xFFFFF5F7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plan Date Tonight',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1820),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF8E717D)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Title Field
              const Text(
                'Date Title',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Candlelit Dinner',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: const Color(0xFFFFECEF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Location Field
              const Text(
                'Location (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Bella Italia Restaurant',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: const Color(0xFFFFECEF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // DateTime Picker
              const Text(
                'Date & Time',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E717D)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFB5003F)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateTime != null
                              ? DateFormat('EEEE, MMM d, y • h:mm a').format(_selectedDateTime!)
                              : 'Select Date & Time',
                          style: TextStyle(
                            color: _selectedDateTime != null ? const Color(0xFF2C1820) : Colors.black26,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFB5003F), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB5003F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Propose Date Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.favorite_border_rounded, size: 16),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
