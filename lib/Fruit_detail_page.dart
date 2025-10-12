import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';

class FruitDetailPage extends StatelessWidget {
  const FruitDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> fruitData = {
      "ส้ม": 5,
      "กล้วย": 6,
      "แอปเปิ้ล": 4,
    };

    final colorList = <Color>[
      Colors.lightGreen,
      Colors.teal,
      Colors.amber,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดผลไม้ในตู้เย็น'),
        backgroundColor: const Color(0xFF6F398E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 30),
            PieChart(
              dataMap: fruitData,
              chartType: ChartType.disc,
              colorList: colorList,
              chartRadius: 200,
              chartValuesOptions: const ChartValuesOptions(
                showChartValuesInPercentage: true,
              ),
              legendOptions: const LegendOptions(
                legendPosition: LegendPosition.right,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "รายละเอียดผลไม้ในตู้เย็น",
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
