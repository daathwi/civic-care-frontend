import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/field_worker.dart';
import '../../models/complaint.dart';
import '../../core/app_theme.dart';
import '../../providers/complaint_provider.dart';
import '../complaint_detail/complaint_detail_screen.dart';
import 'package:intl/intl.dart';

class WorkerDetailScreen extends ConsumerWidget {
  final FieldWorker worker;

  const WorkerDetailScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allComplaints = ref.watch(complaintListProvider);
    final workerTasks = allComplaints
        .where((c) => c.assignedToId == worker.id)
        .toList();
    final activeTasks = workerTasks
        .where((c) => c.status != ComplaintStatus.completed)
        .toList();
    final resolvedTasks = workerTasks
        .where((c) => c.status == ComplaintStatus.completed)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceScaffold,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          elevation: 0,
          title: Text(
            'Field Assistant Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(complaintProvider.notifier).loadGrievances();
          },
          color: Colors.white,
          backgroundColor: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              children: [
              _buildProfileHero(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    _buildContactCard(),
                    const SizedBox(height: 32),

                    // Tab Bar Section
                    TabBar(
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: Colors.grey[400],
                      indicatorColor: AppTheme.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'CURRENT DUTIES'),
                        Tab(text: 'PAST PERFORMANCE'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tab Content Section
                    SizedBox(
                      height: 500, // Sufficient for detailed lists
                      child: TabBarView(
                        children: [
                          _buildTabContent(activeTasks, isGrey: false),
                          _buildTabContent(resolvedTasks, isGrey: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
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

  Widget _buildTabContent(List<Complaint> tasks, {required bool isGrey}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'No records found',
              style: GoogleFonts.outfit(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tasks.length,
      itemBuilder: (context, index) =>
          _buildMinimizedTaskCard(tasks[index], isGrey),
    );
  }

  Widget _buildProfileHero() {
    final statusColor = worker.status == FieldWorkerStatus.onDuty
        ? AppTheme.primary
        : Colors.grey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white24,
                child: Text(
                  worker.name[0],
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            worker.name.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            worker.designation,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              worker.status == FieldWorkerStatus.onDuty
                  ? 'ON DUTY'
                  : 'OFF DUTY',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _statBox(
          'Rating',
          worker.rating.toString(),
          Icons.star_rounded,
          Colors.amber,
        ),
        const SizedBox(width: 12),
        _statBox(
          'Resolved',
          worker.tasksCompleted.toString(),
          Icons.check_circle_rounded,
          const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 12),
        _statBox(
          'Active',
          worker.tasksActive.toString(),
          Icons.pending_rounded,
          const Color(0xFFE65100),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTACT DETAILS',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey[400],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.phone_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Line',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      worker.phone,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {}, // Dummy call action
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('CALL'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jurisdiction',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    worker.lastActiveWard,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedTaskCard(Complaint c, bool isGrey) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaint: c),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isGrey ? Colors.grey : AppTheme.primary).withValues(
                    alpha: 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGrey
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_rounded,
                  color: isGrey ? Colors.grey : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd').format(c.date),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
