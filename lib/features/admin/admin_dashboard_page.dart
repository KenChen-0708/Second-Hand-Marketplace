import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../state/state.dart';
import '../../models/models.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    context.read<AdminUserState>().fetchAllUsers();
    context.read<ProductState>().fetchProducts(status: null);
    context.read<OrderState>().fetchAllOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _fetchData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Overview',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // KPIs using real data from Providers
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Consumer3<AdminUserState, ProductState, OrderState>(
                      builder: (context, userState, productState, orderState, child) {
                        final totalUsers = userState.users.length;
                        final activeListings = productState.items
                            .where((p) => p.status.toLowerCase() == 'active')
                            .length;
                        final completedOrders = orderState.items
                            .where((o) =>
                                o.status.toLowerCase() == 'handed over' ||
                                o.status.toLowerCase() == 'completed')
                            .length;

                        final bool isWide = constraints.maxWidth > 700;

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  context,
                                  'Total Users',
                                  totalUsers.toString(),
                                  Icons.people_alt,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildKpiCard(
                                  context,
                                  'Active Listings',
                                  activeListings.toString(),
                                  Icons.inventory_2,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildKpiCard(
                                  context,
                                  'Completed Handovers',
                                  completedOrders.toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildKpiCard(
                                context,
                                'Total Users',
                                totalUsers.toString(),
                                Icons.people_alt,
                                Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              _buildKpiCard(
                                context,
                                'Active Listings',
                                activeListings.toString(),
                                Icons.inventory_2,
                                Colors.orange,
                                ),
                              const SizedBox(height: 16),
                              _buildKpiCard(
                                context,
                                'Completed Handovers',
                                completedOrders.toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ],
                          );
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

                Text(
                  'Sustainability Impact: Items Saved from Landfills',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Consumer<OrderState>(
                    builder: (context, orderState, child) {
                      final spots = _generateTrendSpots(orderState.items);
                      double maxY = 10;
                      for (var spot in spots) {
                        if (spot.y > maxY) maxY = spot.y;
                      }
                      // Give some padding at the top
                      maxY = (maxY * 1.2).ceilToDouble();

                      return LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
                                  if (value.toInt() >= 0 && value.toInt() < months.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        months[value.toInt()],
                                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _generateTrendSpots(List<OrderModel> orders) {
    // 1. Group completed orders by month of the current year
    final now = DateTime.now();
    final Map<int, int> monthlyCounts = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 // Jan to Jul
    };

    for (var order in orders) {
      if (order.status.toLowerCase() == 'completed' || order.status.toLowerCase() == 'handed over') {
        final date = order.createdAt ?? now;
        if (date.year == now.year && monthlyCounts.containsKey(date.month)) {
          monthlyCounts[date.month] = monthlyCounts[date.month]! + 1;
        }
      }
    }

    // 2. Convert to FlSpots
    return [
      FlSpot(0, monthlyCounts[1]!.toDouble()),
      FlSpot(1, monthlyCounts[2]!.toDouble()),
      FlSpot(2, monthlyCounts[3]!.toDouble()),
      FlSpot(3, monthlyCounts[4]!.toDouble()),
      FlSpot(4, monthlyCounts[5]!.toDouble()),
      FlSpot(5, monthlyCounts[6]!.toDouble()),
      FlSpot(6, monthlyCounts[7]!.toDouble()),
    ];
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
