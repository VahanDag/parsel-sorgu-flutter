import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_event.dart';
import 'package:parsel_sorgu/constants/location_constants.dart';

class ManualSearchWidget extends StatefulWidget {
  const ManualSearchWidget({super.key});

  @override
  State<ManualSearchWidget> createState() => _ManualSearchWidgetState();
}

class _ManualSearchWidgetState extends State<ManualSearchWidget> {
  final TextEditingController _adaNoController = TextEditingController();
  final TextEditingController _parselNoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  List<String> _filteredItems = [];

  @override
  void dispose() {
    _adaNoController.dispose();
    _parselNoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canSearch {
    return _selectedProvince != null &&
        _selectedDistrict != null &&
        _selectedNeighborhood != null &&
        _adaNoController.text.trim().isNotEmpty &&
        _parselNoController.text.trim().isNotEmpty;
  }

  void _onProvinceSelected(String province) {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedNeighborhood = null;
    });
  }

  void _onDistrictSelected(String district) {
    setState(() {
      _selectedDistrict = district;
      _selectedNeighborhood = null;
    });
  }

  void _onNeighborhoodSelected(String neighborhood) {
    setState(() {
      _selectedNeighborhood = neighborhood;
    });
  }

  void _performManualSearch() {
    if (_canSearch) {
      context.read<ParselSearchingBloc>().add(
            ManualSearchEvent(
              province: _selectedProvince!,
              district: _selectedDistrict!,
              neighborhood: _selectedNeighborhood!,
              adaNo: _adaNoController.text.trim(),
              parselNo: _parselNoController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manuel Parsel Sorgulama',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Province Selection
            _buildSelectionField(
              label: 'İl',
              value: _selectedProvince,
              onTap: () => _showBottomSheet(
                title: 'İl Seçiniz',
                items: LocationConstants.getProvinces(),
                searchFunction: LocationConstants.searchProvinces,
                onSelected: _onProvinceSelected,
                selectedValue: _selectedProvince,
              ),
            ),
            const SizedBox(height: 12),

            // District Selection
            _buildSelectionField(
              label: 'İlçe',
              value: _selectedDistrict,
              enabled: _selectedProvince != null,
              onTap: _selectedProvince != null
                  ? () => _showBottomSheet(
                        title: 'İlçe Seçiniz',
                        items: LocationConstants.getDistricts(_selectedProvince!),
                        searchFunction: (query) => LocationConstants.searchDistricts(_selectedProvince!, query),
                        onSelected: _onDistrictSelected,
                        selectedValue: _selectedDistrict,
                      )
                  : null,
            ),
            const SizedBox(height: 12),

            // Neighborhood Selection
            _buildSelectionField(
              label: 'Mahalle',
              value: _selectedNeighborhood,
              enabled: _selectedDistrict != null && _selectedProvince != null,
              onTap: (_selectedDistrict != null && _selectedProvince != null)
                  ? () => _showBottomSheet(
                        title: 'Mahalle Seçiniz',
                        items: LocationConstants.getNeighborhoods(_selectedDistrict!, _selectedProvince!),
                        searchFunction: (query) => LocationConstants.searchNeighborhoods(
                          district: _selectedDistrict!,
                          province: _selectedProvince!,
                          query: query,
                        ),
                        onSelected: _onNeighborhoodSelected,
                        selectedValue: _selectedNeighborhood,
                      )
                  : null,
            ),
            const SizedBox(height: 12),

            // Ada No and Parsel No
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _adaNoController,
                    decoration: const InputDecoration(
                      labelText: 'Ada No',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _parselNoController,
                    decoration: const InputDecoration(
                      labelText: 'Parsel No',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Button
            ElevatedButton(
              onPressed: _canSearch ? _performManualSearch : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'TKGM Sorgusuna Git',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionField({
    required String label,
    required String? value,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? Colors.white : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Seçiniz',
                    style: TextStyle(
                      fontSize: 16,
                      color: value != null
                          ? (enabled ? Colors.black87 : Colors.grey.shade500)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet({
    required String title,
    required List<String> items,
    required List<String> Function(String) searchFunction,
    required Function(String) onSelected,
    required String? selectedValue,
  }) {
    _searchController.clear();
    _filteredItems = items;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Ara...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            _filteredItems = searchFunction(value);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // List
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item == selectedValue;

                          return ListTile(
                            title: Text(
                              item,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Theme.of(context).primaryColor : null,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}