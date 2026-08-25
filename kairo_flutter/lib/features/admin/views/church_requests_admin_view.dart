import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../events/constants/events_constants.dart';
import '../../events/models/church_application.dart';
import '../../events/providers/church_admin_provider.dart';

class ChurchRequestsAdminView extends StatefulWidget {
  const ChurchRequestsAdminView({super.key});

  @override
  State<ChurchRequestsAdminView> createState() => _ChurchRequestsAdminViewState();
}

class _ChurchRequestsAdminViewState extends State<ChurchRequestsAdminView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChurchAdminProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<ChurchAdminProvider>();

    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KairoColors.darkText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Solicitudes pendientes',
          style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: admin.loading || admin.actionLoading ? null : () => admin.load(),
            icon: const Icon(Icons.refresh, color: KairoColors.darkTextSecondary),
          ),
        ],
      ),
      body: _buildBody(admin),
    );
  }

  Widget _buildBody(ChurchAdminProvider admin) {
    if (admin.loading) {
      return const Center(child: CircularProgressIndicator(color: KairoColors.primary500));
    }

    if (!admin.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes permisos de administrador.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 16),
          ),
        ),
      );
    }

    if (admin.error != null && admin.pendingApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(admin.error!, textAlign: TextAlign.center, style: const TextStyle(color: KairoColors.errorText)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: admin.load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (admin.pendingApplications.isEmpty) {
      return const Center(
        child: Text(
          'No hay solicitudes pendientes.',
          style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: admin.pendingApplications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _ChurchRequestCard(
        application: admin.pendingApplications[i],
        busy: admin.actionLoading,
        onApprove: () => _confirmAction(context, admin, admin.pendingApplications[i].id, approve: true),
        onReject: () => _confirmAction(context, admin, admin.pendingApplications[i].id, approve: false),
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context,
    ChurchAdminProvider admin,
    String churchId, {
    required bool approve,
  }) async {
    String? motivoRechazo;

    if (approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KairoColors.darkCard,
          title: const Text('¿Aprobar iglesia?', style: TextStyle(color: KairoColors.darkText)),
          content: const Text(
            'La iglesia quedará activa y visible en la app.',
            style: TextStyle(color: KairoColors.darkTextSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aprobar', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    } else {
      final motivoController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KairoColors.darkCard,
          title: const Text('¿Rechazar solicitud?', style: TextStyle(color: KairoColors.darkText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'La solicitud quedará rechazada.',
                style: TextStyle(color: KairoColors.darkTextSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoController,
                maxLines: 3,
                style: const TextStyle(color: KairoColors.darkText),
                decoration: InputDecoration(
                  hintText: 'Motivo del rechazo (opcional)',
                  hintStyle: TextStyle(color: KairoColors.darkTextSecondary.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: KairoColors.darkHover,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      motivoRechazo = motivoController.text.trim().isEmpty ? null : motivoController.text.trim();
    }

    final err = approve
        ? await admin.approve(churchId)
        : await admin.reject(churchId, motivoRechazo: motivoRechazo);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? (approve ? 'Iglesia aprobada' : 'Solicitud rechazada')),
        backgroundColor: err != null ? KairoColors.errorText : null,
      ),
    );
  }
}

class _ChurchRequestCard extends StatelessWidget {
  const _ChurchRequestCard({
    required this.application,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ChurchApplication application;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final denomination = denominationNames[application.denomination] ?? application.denomination;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.name,
                  style: const TextStyle(color: KairoColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Pendiente', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Denominación', value: denomination),
          _DetailRow(label: 'País', value: application.countryName),
          _DetailRow(label: 'Ciudad', value: application.city),
          _DetailRow(label: 'Pastor / líder', value: application.responsibleLeader),
          if (application.pastorEmail.isNotEmpty)
            _DetailRow(label: 'Correo del pastor', value: application.pastorEmail),
          if (application.creatorEmail != null) _DetailRow(label: 'Solicitante', value: application.creatorEmail!),
          if (application.isSouthAmerica && application.fiscalId != null)
            _DetailRow(label: 'Identificador fiscal', value: application.fiscalId!),
          if (application.facebookUrl != null) _LinkRow(label: 'Facebook', url: application.facebookUrl!),
          if (application.instagramUrl != null) _LinkRow(label: 'Instagram', url: application.instagramUrl!),
          if (application.legalDocumentUrl != null) _LinkRow(label: 'Documento legal', url: application.legalDocumentUrl!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: KairoColors.darkText, fontSize: 13))),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enlace copiado: $label')));
              },
              child: Text(
                url,
                style: const TextStyle(color: KairoColors.primary400, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
