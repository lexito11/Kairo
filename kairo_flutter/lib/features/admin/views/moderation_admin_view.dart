import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../events/services/churches_repository.dart';
import '../../moderation/services/moderation_repository.dart';

class ModerationAdminView extends StatefulWidget {
  const ModerationAdminView({super.key});

  @override
  State<ModerationAdminView> createState() => _ModerationAdminViewState();
}

class _ModerationAdminViewState extends State<ModerationAdminView>
    with SingleTickerProviderStateMixin {
  final _repo = ModerationRepository();
  final _churches = ChurchesRepository();

  late final TabController _tabs;
  bool _loading = true;
  bool _isAdmin = false;
  bool _acting = false;
  String? _error;
  List<ModerationReport> _reports = [];
  List<BlockedAccountRow> _blocked = [];
  List<ModerationQueueItem> _queue = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admin = await _churches.isCurrentUserAdmin();
      if (!admin) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }
      final reports = await _repo.fetchPendingReports();
      final blocked = await _repo.fetchBlockedAccounts();
      var queue = <ModerationQueueItem>[];
      try {
        queue = await _repo.fetchQueue();
      } catch (_) {}
      await _repo.flushAdminEmails();
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _reports = reports;
        _blocked = blocked;
        _queue = queue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _review(ModerationReport report, {required bool confirm}) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result = await _repo.reviewReport(report.id, confirm: confirm);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final text = !confirm
          ? 'Reporte descartado. No se registró infracción.'
          : result.duplicate
              ? 'Esa infracción ya estaba registrada. No se duplicó.'
              : result.accountBlocked
                  ? 'Infracción ${result.infractionCount} confirmada. La cuenta quedó bloqueada.'
                  : 'Infracción ${result.infractionCount} registrada. La cuenta sigue activa.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reviewQueue(ModerationQueueItem item, {required String action}) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result = await _repo.reviewQueueItem(item.id, action: action);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final text = action == 'approve'
          ? 'Contenido marcado como permitido. No hay infracción.'
          : result.duplicate
              ? 'Esa infracción ya estaba registrada. No se duplicó.'
              : result.accountBlocked
                  ? 'Infracción ${result.infractionCount}. La cuenta quedó bloqueada.'
                  : 'Infracción ${result.infractionCount} registrada.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openHistory(String userId, String title) async {
    try {
      final items = await _repo.fetchUserInfractions(userId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: KairoColors.darkCard,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _InfractionHistorySheet(
          title: title,
          userId: userId,
          items: items,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KairoColors.darkText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Moderación',
          style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _acting ? null : _load,
            icon: const Icon(Icons.refresh, color: KairoColors.darkTextSecondary),
          ),
        ],
        bottom: _isAdmin
            ? TabBar(
                controller: _tabs,
                indicatorColor: KairoColors.primary500,
                labelColor: KairoColors.darkText,
                unselectedLabelColor: KairoColors.darkTextSecondary,
                tabs: [
                  Tab(text: 'Reportes (${_reports.length})'),
                  Tab(text: 'Cola (${_queue.length})'),
                  Tab(text: 'Bloqueadas (${_blocked.length})'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: KairoColors.primary500));
    }
    if (!_isAdmin) {
      return const Center(
        child: Text(
          'No tienes permisos de administrador.',
          style: TextStyle(color: KairoColors.darkTextSecondary),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: KairoColors.errorText)),
        ),
      );
    }
    return TabBarView(
      controller: _tabs,
      children: [
        _reports.isEmpty
            ? const Center(
                child: Text(
                  'No hay reportes pendientes.',
                  style: TextStyle(color: KairoColors.darkTextSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ReportCard(
                  report: _reports[i],
                  busy: _acting,
                  onConfirm: () => _review(_reports[i], confirm: true),
                  onDismiss: () => _review(_reports[i], confirm: false),
                ),
              ),
        _queue.isEmpty
            ? const Center(
                child: Text(
                  'No hay elementos pendientes en la cola.',
                  style: TextStyle(color: KairoColors.darkTextSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _queue.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _QueueCard(
                  item: _queue[i],
                  busy: _acting,
                  onConfirm: () => _reviewQueue(_queue[i], action: 'confirm'),
                  onApprove: () => _reviewQueue(_queue[i], action: 'approve'),
                ),
              ),
        _blocked.isEmpty
            ? const Center(
                child: Text(
                  'No hay cuentas bloqueadas.',
                  style: TextStyle(color: KairoColors.darkTextSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _blocked.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final row = _blocked[i];
                  return Material(
                    color: KairoColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      title: Text(
                        row.displayName,
                        style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${row.email}\n${row.blockedReason ?? '4 infracciones acumuladas'} · ${row.infractionCount} infracciones',
                        style: const TextStyle(color: KairoColors.darkTextSecondary, height: 1.35),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
                      onTap: () => _openHistory(row.userId, row.displayName),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.busy,
    required this.onConfirm,
    required this.onApprove,
  });

  final ModerationQueueItem item;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.status} · ${item.contentType}',
            style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            item.contentId,
            style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
          ),
          if (item.analysisNotes != null && item.analysisNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.analysisNotes!,
              style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(onPressed: busy ? null : onApprove, child: const Text('Permitir')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onConfirm,
                style: FilledButton.styleFrom(backgroundColor: KairoColors.primary500),
                child: const Text('Confirmar infracción'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
  });

  final ModerationReport report;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.reason,
            style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${report.targetType} · ${report.targetId}',
            style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            report.createdAt.toUtc().toIso8601String(),
            style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: busy ? null : onDismiss,
                child: const Text('Descartar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onConfirm,
                style: FilledButton.styleFrom(backgroundColor: KairoColors.primary500),
                child: const Text('Confirmar infracción'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfractionHistorySheet extends StatelessWidget {
  const _InfractionHistorySheet({
    required this.title,
    required this.userId,
    required this.items,
  });

  final String title;
  final String userId;
  final List<ContentInfraction> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: KairoColors.darkText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Identificador copiado')),
                );
              },
              child: Text(
                userId,
                style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text(
                'No hay infracciones conservadas.',
                style: TextStyle(color: KairoColors.darkTextSecondary),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: KairoColors.darkHover,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Infracción ${i + 1}\n'
                        'Categoría: ${item.category}\n'
                        'Motivo: ${item.reason}\n'
                        'Fecha: ${item.createdAt.toUtc().toIso8601String()}\n'
                        'Contenido: ${item.contentType} / ${item.contentId}\n'
                        'Estado: ${item.status}'
                        '${item.detectionMethod == null || item.detectionMethod!.isEmpty ? '' : '\nDetección: ${item.detectionMethod}'}'
                        '${item.mediaRef == null || item.mediaRef!.isEmpty ? '' : '\nReferencia: ${item.mediaRef}'}'
                        '${item.storageDeleted ? '\nArchivo de Storage eliminado.' : ''}'
                        '${item.contentRemoved ? '\nEl contenido fue eliminado. El historial se conserva.' : ''}',
                        style: const TextStyle(
                          color: KairoColors.darkText,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
