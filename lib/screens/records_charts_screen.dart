import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:zerov7/models/device.dart';

// Data Models
class HistoricalData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double airQuality;

  HistoricalData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
  });

  factory HistoricalData.fromMap(String key, Map<dynamic, dynamic> value) {
    return HistoricalData(
      timestamp: DateTime.parse(key),
      temperature: (value['temperature'] ?? 0).toDouble(),
      humidity: (value['humidity'] ?? 0).toDouble(),
      airQuality: (value['air_quality'] ?? 0).toDouble(),
    );
  }
}

class DailyAverage {
  final DateTime date;
  final double averageTemperature;
  final double averageHumidity;
  final double averageAirQuality;

  DailyAverage({
    required this.date,
    required this.averageTemperature,
    required this.averageHumidity,
    required this.averageAirQuality,
  });

  factory DailyAverage.fromMap(String key, Map<dynamic, dynamic> value) {
    return DailyAverage(
      date: DateTime.parse(key),
      averageTemperature: (value['averageTemperature'] ?? 0).toDouble(),
      averageHumidity: (value['averageHumidity'] ?? 0).toDouble(),
      averageAirQuality: (value['averageAirQuality'] ?? 0).toDouble(),
    );
  }
}

class HistogramData {
  final String day;
  final double averageTemperature;
  final double averageHumidity;
  final double averageAirQuality;

  HistogramData({
    required this.day,
    required this.averageTemperature,
    required this.averageHumidity,
    required this.averageAirQuality,
  });
}

class RecordsChartsScreen extends StatefulWidget {
  final Device? device;

  const RecordsChartsScreen({Key? key, this.device, required String deviceId}) : super(key: key);

  @override
  _RecordsChartsScreenState createState() => _RecordsChartsScreenState();
}

class _RecordsChartsScreenState extends State<RecordsChartsScreen> {
  DatabaseReference? _readingsRef;
  DatabaseReference? _dailyAveragesRef;

  // Removed unused userId variable

  List<HistoricalData> _readingsData = [];
  List<DailyAverage> _dailyAveragesData = [];

  StreamSubscription<DatabaseEvent>? readingsSubscription;
  StreamSubscription<DatabaseEvent>? dailyAveragesSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _initializeFirebaseReferences(widget.device!.deviceId);
      _fetchReadingsData();
      _fetchDailyAveragesData();
    }
  }

  @override
  void didUpdateWidget(covariant RecordsChartsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device?.deviceId != widget.device?.deviceId) {
      readingsSubscription?.cancel();
      dailyAveragesSubscription?.cancel();
      if (widget.device != null) {
        _initializeFirebaseReferences(widget.device!.deviceId);
        _fetchReadingsData();
        _fetchDailyAveragesData();
      } else {
        setState(() {
          _readingsData = [];
          _dailyAveragesData = [];
        });
      }
    }
  }

  @override
  void dispose() {
    readingsSubscription?.cancel();
    dailyAveragesSubscription?.cancel();
    super.dispose();
  }

  // bring Firebase References based on deviceId
  void _initializeFirebaseReferences(String deviceId) {
    _readingsRef = FirebaseDatabase.instance.ref('$deviceId/15_min_readings');
    _dailyAveragesRef = FirebaseDatabase.instance.ref('$deviceId/daily_averages');
  }

  // Fetch data from 15_min_readings
  void _fetchReadingsData() {
    if (_readingsRef == null) return;
    readingsSubscription = _readingsRef!.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<HistoricalData> readings = [];
        data.forEach((key, value) {
          try {
            if (value is Map<dynamic, dynamic>) {
              readings.add(HistoricalData.fromMap(key, value));
            } else {
              print('Invalid data format for key: $key');
            }
          } catch (e) {
            print('Error parsing reading data: $value. Error: $e');
          }
        });

        // Sort readings by timestamp ascending
        readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Filter data for the last 5 hours
        DateTime now = DateTime.now();
        DateTime fiveHoursAgo = now.subtract(const Duration(hours: 5));

        readings = readings
            .where((data) =>
        data.timestamp.isAfter(fiveHoursAgo) &&
            data.timestamp.isBefore(now))
            .toList();

        setState(() {
          _readingsData = readings;

        });
      } else {
        print('No readings data found in Firebase');
      }
    }, onError: (error) {
      print("Error listening to readings data: $error");
    });
  }

  // Fetch data from daily_averages
  void _fetchDailyAveragesData() {
    if (_dailyAveragesRef == null) return;
    dailyAveragesSubscription = _dailyAveragesRef!.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<DailyAverage> dailyAverages = [];
        data.forEach((date, timeValues) {
          if (timeValues is Map<dynamic, dynamic>) {
            double sumTemperature = 0;
            double sumHumidity = 0;
            double sumAirQuality = 0;
            int count = 0;

            timeValues.forEach((time, values) {
              try {
                if (values is Map<dynamic, dynamic>) {
                  sumTemperature += (values['temperature'] ?? 0).toDouble();
                  sumHumidity += (values['humidity'] ?? 0).toDouble();
                  sumAirQuality += (values['air_quality'] ?? 0).toDouble();
                  count++;
                } else {
                  print('Invalid data format for time: $time');
                }
              } catch (e) {
                print('Error parsing daily average data: $values. Error: $e');
              }
            });

            if (count > 0) {
              dailyAverages.add(DailyAverage(
                date: DateTime.parse(date),
                averageTemperature: sumTemperature / count,
                averageHumidity: sumHumidity / count,
                averageAirQuality: sumAirQuality / count,
              ));
            }
          } else {
            print('Invalid data format for date: $date');
          }
        });

        setState(() {
          _dailyAveragesData = dailyAverages;

        });
      } else {
        print('No daily averages data found in Firebase');
      }
    }, onError: (error) {
      print("Error listening to daily averages data: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.device == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Charts'),
        ),
        body: const Center(
          child: Text(
            "No device selected.",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.device!.name} 📈',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: '🌡️&🌫️'),
              Tab(text: 'Air Quality'),
              Tab(text: 'Weekly Avg'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTemperatureHumidityCharts(),
            _buildAirQualityChart(),
            _buildWeeklyHistogram(),
          ],
        ),
      ),
    );
  }

  // Tab 1: Temperature and Humidity Charts
  Widget _buildTemperatureHumidityCharts() {
    return Column(
      children: [
        Expanded(child: _buildTemperatureChart()),
        Expanded(child: _buildHumidityChart()),
      ],
    );
  }

  // Temperature Trend Chart
  Widget _buildTemperatureChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: 'Temperature Trend (Last 5 Hours)',
        textStyle: const TextStyle(color: Colors.greenAccent),
      ),
      legend: Legend(isVisible: false),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: DateTimeAxis(
        intervalType: DateTimeIntervalType.minutes,
        interval: 30,
        dateFormat: DateFormat('h:mm a'),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 50, // Adjust based on expected temperature range
        title: AxisTitle(text: 'Temperature (°C)'),
      ),
      series: <CartesianSeries<HistoricalData, DateTime>>[
        LineSeries<HistoricalData, DateTime>(
          dataSource: _readingsData,
          xValueMapper: (HistoricalData data, _) => data.timestamp,
          yValueMapper: (HistoricalData data, _) => data.temperature,
          name: 'Temperature (°C)',
          color: Colors.redAccent,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }

  // Humidity Trend Chart
  Widget _buildHumidityChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: 'Humidity Trend (Last 5 Hours)',
        textStyle: const TextStyle(color: Colors.greenAccent),
      ),
      legend: Legend(isVisible: false),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: DateTimeAxis(
        intervalType: DateTimeIntervalType.minutes,
        interval: 30,
        dateFormat: DateFormat('h:mm a'),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 100, // Humidity percentage
        title: AxisTitle(text: 'Humidity (%)'),
      ),
      series: <CartesianSeries<HistoricalData, DateTime>>[
        LineSeries<HistoricalData, DateTime>(
          dataSource: _readingsData,
          xValueMapper: (HistoricalData data, _) => data.timestamp,
          yValueMapper: (HistoricalData data, _) => data.humidity,
          name: 'Humidity (%)',
          color: Colors.blueAccent,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }

  // Tab 2: Air Quality Chart
  Widget _buildAirQualityChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: 'Air Quality Trend (Last 5 Hours)',
        textStyle: const TextStyle(color: Colors.greenAccent),
      ),
      legend: Legend(isVisible: false),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: DateTimeAxis(
        intervalType: DateTimeIntervalType.minutes,
        interval: 30,
        dateFormat: DateFormat('h:mm a'),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 500,
        title: AxisTitle(text: 'Air Quality Index'),
      ),
      series: <CartesianSeries<HistoricalData, DateTime>>[
        LineSeries<HistoricalData, DateTime>(
          dataSource: _readingsData,
          xValueMapper: (HistoricalData data, _) => data.timestamp,
          yValueMapper: (HistoricalData data, _) => data.airQuality,
          name: 'AQI',
          color: Colors.green,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }

  // Tab 3: Weekly Histogram
  Widget _buildWeeklyHistogram() {
    // Group daily averages by weekday
    Map<int, List<DailyAverage>> groupedData = {};

    for (var average in _dailyAveragesData) {
      int weekday = average.date.weekday;
      groupedData.putIfAbsent(weekday, () => []).add(average);
    }

    // Calculate average per weekday
    List<HistogramData> histogramData = [];
    for (int i = DateTime.monday; i <= DateTime.sunday; i++) {
      List<DailyAverage>? dayData = groupedData[i];
      if (dayData != null && dayData.isNotEmpty) {
        double avgTemp = dayData
            .map((data) => data.averageTemperature)
            .reduce((a, b) => a + b) /
            dayData.length;
        double avgHum = dayData
            .map((data) => data.averageHumidity)
            .reduce((a, b) => a + b) /
            dayData.length;
        double avgAQI = dayData
            .map((data) => data.averageAirQuality)
            .reduce((a, b) => a + b) /
            dayData.length;

        // Round to 1 decimal point
        avgTemp = double.parse(avgTemp.toStringAsFixed(1));
        avgHum = double.parse(avgHum.toStringAsFixed(1));
        avgAQI = double.parse(avgAQI.toStringAsFixed(1));

        String dayName = _weekdayToString(i);
        histogramData.add(HistogramData(
          day: dayName,
          averageTemperature: avgTemp,
          averageHumidity: avgHum,
          averageAirQuality: avgAQI,
        ));
      } else {
        String dayName = _weekdayToString(i);
        histogramData.add(HistogramData(
          day: dayName,
          averageTemperature: 0,
          averageHumidity: 0,
          averageAirQuality: 0,
        ));
      }
    }

    return SfCartesianChart(
      title: ChartTitle(
        text: 'Weekly Averages',
        textStyle: const TextStyle(color: Colors.greenAccent),
      ),
      legend: Legend(isVisible: true),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: 'Day of the Week'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Average Value'),
      ),
      series: <CartesianSeries<HistogramData, String>>[
        ColumnSeries<HistogramData, String>(
          dataSource: histogramData,
          xValueMapper: (HistogramData data, _) => data.day,
          yValueMapper: (HistogramData data, _) => data.averageAirQuality,
          name: 'Average AQI',
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          color: Colors.yellow,
          spacing: 0.6,
        ),
        ColumnSeries<HistogramData, String>(
          dataSource: histogramData,
          xValueMapper: (HistogramData data, _) => data.day,
          yValueMapper: (HistogramData data, _) => data.averageTemperature,
          name: 'Average Temp',
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          color: Colors.red,
          spacing: 0.6,
        ),
        ColumnSeries<HistogramData, String>(
          dataSource: histogramData,
          xValueMapper: (HistogramData data, _) => data.day,
          yValueMapper: (HistogramData data, _) => data.averageHumidity,
          name: 'Average Humidity (%)',
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          color: Colors.blue,
          spacing: 0.6,
        ),
      ],
    );
  }


  // convert weekday integer to string
  String _weekdayToString(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}