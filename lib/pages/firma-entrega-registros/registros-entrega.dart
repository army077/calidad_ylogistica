// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sistema_rastreabilidad/services/logistica_delivery_list_service.dart';

class Registroentregas extends StatefulWidget {
  const Registroentregas({super.key, this.service});

  final LogisticaDeliveryListService? service;

  @override
  State<Registroentregas> createState() => _RegistroentregasState();
}

class _RegistroentregasState extends State<Registroentregas> {
  late final LogisticaDeliveryListService _service;
  final _searchController = TextEditingController();
  final _items = <LogisticaDeliveryListItem>[];
  Timer? _searchDebounce;
  String _pedido = '';
  String? _nextCursor;
  String? _initialError;
  String? _moreError;
  bool _initialLoading = true;
  bool _loadingMore = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LogisticaDeliveryListService();
    unawaited(_fetchFirstPage(++_requestVersion, _pedido));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final pedido = value.trim();
    if (pedido == _pedido) {
      setState(() {});
      return;
    }
    _pedido = pedido;
    _reload(debounce: true);
  }

  void _reload({bool debounce = false}) {
    _searchDebounce?.cancel();
    final version = ++_requestVersion;
    final pedido = _pedido;
    setState(() {
      _items.clear();
      _nextCursor = null;
      _initialError = null;
      _moreError = null;
      _initialLoading = true;
      _loadingMore = false;
    });
    if (debounce) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        unawaited(_fetchFirstPage(version, pedido));
      });
    } else {
      unawaited(_fetchFirstPage(version, pedido));
    }
  }

  Future<void> _fetchFirstPage(int version, String pedido) async {
    try {
      final page = await _service.fetchPage(
        pedido: pedido.isEmpty ? null : pedido,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _appendUnique(page.items);
        _nextCursor = page.nextCursor;
        _initialLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _initialError = _errorMessage(error);
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_initialLoading || _loadingMore || _nextCursor == null) return;
    final version = _requestVersion;
    final cursor = _nextCursor!;
    final pedido = _pedido;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _service.fetchPage(
        pedido: pedido.isEmpty ? null : pedido,
        cursor: cursor,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _appendUnique(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _moreError = _errorMessage(error);
        _loadingMore = false;
      });
    }
  }

  void _appendUnique(List<LogisticaDeliveryListItem> items) {
    final ids = _items.map((item) => item.id).toSet();
    _items.addAll(items.where((item) => ids.add(item.id)));
  }

  String _errorMessage(Object error) => error is LogisticaDeliveryListException
      ? error.message
      : 'No se pudieron cargar las entregas. Reintenta la consulta.';

  Widget _buildContent() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initialError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_initialError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _reload(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _pedido.isEmpty
              ? 'No hay entregas registradas.'
              : 'No se encontraron pedidos.',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }
    return ListView.builder(
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index < _items.length) return _deliveryCard(_items[index]);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_loadingMore)
                const CircularProgressIndicator()
              else if (_moreError != null) ...[
                Text(_moreError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loadMore,
                  child: const Text('Reintentar'),
                ),
              ] else if (_nextCursor != null)
                OutlinedButton(
                  onPressed: _loadMore,
                  child: const Text('Cargar más'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _deliveryCard(LogisticaDeliveryListItem item) {
    final localDateTime = item.createdAt.toLocal();
    final name = item.authDisplayName;
    return Card(
      key: ValueKey(item.id),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        key: PageStorageKey(item.id),
        title: Text(
          name == null || name.trim().isEmpty ? 'Usuario' : name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Pedido: ${item.pedido}',
          style: const TextStyle(fontSize: 16),
        ),
        children: [
          ListTile(
            title: Text(
              'Correo: ${item.authEmail ?? 'No disponible'}',
              style: const TextStyle(fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fecha: ${DateFormat('yyyy-MM-dd').format(localDateTime)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 7),
                Text(
                  'Hora: ${DateFormat('hh:mm:ss a').format(localDateTime)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 7),
                Text.rich(
                  TextSpan(children: [
                    const WidgetSpan(
                      child: Icon(Icons.check_circle, size: 14),
                      baseline: TextBaseline.ideographic,
                      alignment: PlaceholderAlignment.middle,
                    ),
                    TextSpan(
                      text: 'Img Subidas: ${item.photoCount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(22, 23, 24, 0.8),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Container(
                color: Colors.white,
                child: Image.asset('lib/images/ar_inicio.png', height: 44),
              ),
              const SizedBox(width: 10),
              const Text('entregas'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _reload(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Buscar pedidos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
