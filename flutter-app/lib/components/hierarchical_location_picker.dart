import 'package:flutter/material.dart';
import '../services/location_service.dart';

class HierarchicalLocationPicker extends StatefulWidget {
  final String? initialCity;
  final Function(String cityName) onCitySelected;
  final bool showCurrentLocation;

  const HierarchicalLocationPicker({
    super.key,
    this.initialCity,
    required this.onCitySelected,
    this.showCurrentLocation = true,
  });

  @override
  State<HierarchicalLocationPicker> createState() => _HierarchicalLocationPickerState();
}

class _HierarchicalLocationPickerState extends State<HierarchicalLocationPicker> {
  String? _selectedProvince;
  String? _selectedCity;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null) {
      _selectedCity = widget.initialCity;
      _selectedProvince = LocationService.findProvinceByCity(widget.initialCity!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 선택된 위치 표시 헤더
          _buildSelectedLocationHeader(),
          
          // 확장되었을 때 위치 선택 UI
          if (_isExpanded) _buildLocationSelector(),
        ],
      ),
    );
  }

  Widget _buildSelectedLocationHeader() {
    String displayText = '지역 선택';
    IconData displayIcon = Icons.location_city;
    
    if (_selectedCity != null) {
      if (widget.showCurrentLocation && _selectedCity == '현재 위치') {
        displayText = '현재 위치';
        displayIcon = Icons.my_location;
      } else {
        final province = LocationService.findProvinceByCity(_selectedCity!);
        displayText = province != null ? '$province · $_selectedCity' : _selectedCity!;
        displayIcon = Icons.location_city;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Icon(
                displayIcon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 현재 위치 옵션 (활성화된 경우)
            if (widget.showCurrentLocation) _buildCurrentLocationOption(),
            
            // 도/특별시 목록
            ...LocationService.provinces.map((province) => _buildProvinceSection(province)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationOption() {
    final isSelected = _selectedCity == '현재 위치';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCity = '현재 위치';
            _selectedProvince = null;
            _isExpanded = false;
          });
          widget.onCitySelected('현재 위치');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.my_location,
                size: 18,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Text(
                '현재 위치',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProvinceSection(String province) {
    final cities = LocationService.getCitiesByProvince(province);
    final isProvinceExpanded = _selectedProvince == province;
    
    return Column(
      children: [
        // 도/특별시 헤더
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (_selectedProvince == province) {
                  _selectedProvince = null;
                } else {
                  _selectedProvince = province;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      province,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isProvinceExpanded 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // 시/군 목록 (확장된 경우)
        if (isProvinceExpanded) ...[
          Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: cities.map((city) => _buildCityOption(city, province)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCityOption(String city, String province) {
    final isSelected = _selectedCity == city;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCity = city;
            _selectedProvince = province;
            _isExpanded = false;
          });
          widget.onCitySelected(city);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_city,
                size: 16,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Text(
                city,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}