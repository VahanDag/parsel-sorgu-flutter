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
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _adaNoController = TextEditingController();
  final TextEditingController _parselNoController = TextEditingController();

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedNeighborhood;

  @override
  void dispose() {
    _provinceController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _adaNoController.dispose();
    _parselNoController.dispose();
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
      _provinceController.text = province;
      _districtController.clear();
      _neighborhoodController.clear();
    });
  }

  void _onDistrictSelected(String district) {
    setState(() {
      _selectedDistrict = district;
      _selectedNeighborhood = null;
      _districtController.text = district;
      _neighborhoodController.clear();
    });
  }

  void _onNeighborhoodSelected(String neighborhood) {
    setState(() {
      _selectedNeighborhood = neighborhood;
      _neighborhoodController.text = neighborhood;
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
            SearchableDropdownField(
              controller: _provinceController,
              label: 'İl',
              items: LocationConstants.getProvinces(),
              searchFunction: LocationConstants.searchProvinces,
              onSelected: _onProvinceSelected,
              enabled: true,
            ),
            const SizedBox(height: 12),

            // District Selection
            SearchableDropdownField(
              controller: _districtController,
              label: 'İlçe',
              items: _selectedProvince != null ? LocationConstants.getDistricts(_selectedProvince!) : [],
              searchFunction: _selectedProvince != null ? (query) => LocationConstants.searchDistricts(_selectedProvince!, query) : (query) => <String>[],
              onSelected: _onDistrictSelected,
              enabled: _selectedProvince != null,
            ),
            const SizedBox(height: 12),

            // Neighborhood Selection
            SearchableDropdownField(
              controller: _neighborhoodController,
              label: 'Mahalle',
              items: (_selectedDistrict != null && _selectedProvince != null) ? LocationConstants.getNeighborhoods(_selectedDistrict!, _selectedProvince!) : [],
              searchFunction: (_selectedDistrict != null && _selectedProvince != null)
                  ? (query) => LocationConstants.searchNeighborhoods(district: _selectedDistrict!, province: _selectedProvince!, query: query)
                  : (query) => <String>[],
              onSelected: _onNeighborhoodSelected,
              enabled: _selectedDistrict != null,
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
}

class SearchableDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> items;
  final List<String> Function(String query) searchFunction;
  final void Function(String) onSelected;
  final bool enabled;

  const SearchableDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.items,
    required this.searchFunction,
    required this.onSelected,
    required this.enabled,
  });

  @override
  State<SearchableDropdownField> createState() => _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends State<SearchableDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(SearchableDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.enabled) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChange() {
    if (widget.enabled) {
      _filteredItems = widget.searchFunction(widget.controller.text);
      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return ListTile(
                    title: Text(item),
                    onTap: () {
                      widget.onSelected(item);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: widget.enabled ? const Icon(Icons.arrow_drop_down) : null,
        ),
        readOnly: false,
      ),
    );
  }
}
