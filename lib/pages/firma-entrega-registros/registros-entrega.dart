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

class _HistorySection {
  _HistorySection(this.source);

  final LogisticaDeliverySource source;
  final items = <LogisticaDeliveryListItem>[];
  String? nextCursor;
  String? moreError;
  bool loadingMore = false;

  void reset() {
    items.clear();
    nextCursor = null;
    moreError = null;
    loadingMore = false;
  }

  void append(LogisticaDeliveryListSection page) {
    final identities = items.map((item) => item.uiKey).toSet();
    items.addAll(page.items.where((item) => identities.add(item.uiKey)));
    nextCursor = page.nextCursor;
  }
}

class _RegistroentregasState extends State<Registroentregas> {
  late final LogisticaDeliveryListService _service;
  final _searchController = TextEditingController();
  final _current = _HistorySection(LogisticaDeliverySource.current);
  final _legacy = _HistorySection(LogisticaDeliverySource.legacy);
  Timer? _searchDebounce;
  String _pedido = '';
  String? _initialError;
  bool _initialLoading = true;
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
      _current.reset();
      _legacy.reset();
      _initialError = null;
      _initialLoading = true;
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
      final page =
          await _service.fetchPage(pedido: pedido.isEmpty ? null : pedido);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _current.append(page.current);
        _legacy.append(page.legacy);
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

  Future<void> _loadMore(_HistorySection section) async {
    if (_initialLoading || section.loadingMore || section.nextCursor == null) {
      return;
    }
    final version = _requestVersion;
    final cursor = section.nextCursor!;
    final pedido = _pedido;
    final isCurrent = section.source == LogisticaDeliverySource.current;
    setState(() {
      section.loadingMore = true;
      section.moreError = null;
    });
    try {
      final page = await _service.fetchPage(
        pedido: pedido.isEmpty ? null : pedido,
        currentCursor: isCurrent ? cursor : null,
        legacyCursor: isCurrent ? null : cursor,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        // The other section is a first page in this response: leave its items
        // AND its cursor untouched, including during concurrent pagination.
        section.append(isCurrent ? page.current : page.legacy);
        section.loadingMore = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        section.moreError = _errorMessage(error);
        section.loadingMore = false;
      });
    }
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_initialError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => _reload(), child: const Text('Reintentar')),
          ]),
        ),
      );
    }
    return CustomScrollView(
      key: ValueKey(_requestVersion),
      slivers: [
        if (_pedido.isNotEmpty &&
            _current.items.isEmpty &&
            _legacy.items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No se encontraron pedidos.')),
          ),
        ..._sectionSlivers(_current),
        ..._sectionSlivers(_legacy),
      ],
    );
  }

  List<Widget> _sectionSlivers(_HistorySection section) {
    final isCurrent = section.source == LogisticaDeliverySource.current;
    final title = isCurrent ? 'Entregas actuales' : 'Registros históricos';
    final emptyMessage = _pedido.isEmpty
        ? (isCurrent
            ? 'No hay entregas actuales.'
            : 'No hay registros históricos asociados.')
        : (isCurrent
            ? 'No se encontraron entregas actuales para este pedido.'
            : 'No se encontraron registros históricos para este pedido.');
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      if (section.items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.all(16), child: Text(emptyMessage)),
        ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _deliveryCard(section.items[index]),
          childCount: section.items.length,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (section.loadingMore)
              CircularProgressIndicator(
                  key: ValueKey('loading-${section.source.name}'))
            else if (section.moreError != null) ...[
              Text(section.moreError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                key: ValueKey('retry-${section.source.name}'),
                onPressed: () => _loadMore(section),
                child: const Text('Reintentar'),
              ),
            ] else if (section.nextCursor != null)
              OutlinedButton(
                key: ValueKey('more-${section.source.name}'),
                onPressed: () => _loadMore(section),
                child: const Text('Cargar más'),
              ),
          ]),
        ),
      ),
    ];
  }

  Widget _deliveryCard(LogisticaDeliveryListItem item) {
    final legacy = item.source == LogisticaDeliverySource.legacy;
    final name = item.displayName;
    return Card(
      key: ValueKey(item.uiKey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        key: PageStorageKey(item.uiKey),
        title: Text(
          legacy
              ? 'Registro histórico'
              : (name == null || name.trim().isEmpty ? 'Usuario' : name),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('Pedido: ${item.pedido}',
            style: const TextStyle(fontSize: 16)),
        children: [
          ListTile(
            title: Text(
              "${legacy ? 'Correo declarado' : 'Correo'}: ${item.email ?? 'No disponible'}",
              style: const TextStyle(fontSize: 16),
            ),
            subtitle: legacy ? _legacyDetails(item) : _currentDetails(item),
          ),
        ],
      ),
    );
  }

  Widget _currentDetails(LogisticaDeliveryListItem item) {
    final localDateTime = item.createdAt!.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Fecha: ${DateFormat('yyyy-MM-dd').format(localDateTime)}"),
        const SizedBox(height: 7),
        Text("Hora: ${DateFormat('hh:mm:ss a').format(localDateTime)}"),
        const SizedBox(height: 7),
        Text.rich(TextSpan(children: [
          const WidgetSpan(
            child: Icon(Icons.check_circle, size: 14),
            baseline: TextBaseline.ideographic,
            alignment: PlaceholderAlignment.middle,
          ),
          TextSpan(text: 'Img Subidas: ${item.photoCount}'),
        ])),
      ],
    );
  }

  Widget _legacyDetails(LogisticaDeliveryListItem item) {
    final clock = item.recordedLocalAt!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Usuario declarado: ${item.displayName ?? 'No disponible'}"),
        const SizedBox(height: 7),
        Text('Fecha registrada: ${clock.substring(0, 10)}'),
        const SizedBox(height: 7),
        Text('Hora registrada: ${clock.substring(11)}'),
        const SizedBox(height: 7),
        const Text('Estado del registro: RECORDED'),
        const SizedBox(height: 7),
        Text(
            'Contador de imágenes legacy (declarado): ${item.legacyImageCount}'),
      ],
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
