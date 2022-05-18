import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import "dart:async";

class BuddycomButton extends StatefulWidget {
  const BuddycomButton({
    Key? key,
    /*  required this.channel */
  }) : super(key: key);
  /* final IOWebSocketChannel channel; */
  @override
  State<BuddycomButton> createState() => _BuddycomButtonState();
}

class WavePainter extends CustomPainter {
  WavePainter({
    required this.samples,
    required this.constraints,
  });

  BoxConstraints constraints;
  Uint8List samples;
  static const Color color = Colors.blue;

  final _absMax = 1;
  static const _hightOffset = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    // 色、太さ、塗り潰しの有無などを指定
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 得られたデータをオフセットのリストに変換する
    // やっていることは決められた範囲で等間隔に点を並べているだけ
    final points = toPoints(samples);

    // addPolygon で path をつくり drawPath でグラフを表現する
    final path = Path()..addPolygon(points, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(oldDelegate) => true;

  // 得られたデータを等間隔に並べていく
  List<Offset> toPoints(Uint8List samples) {
    final points = <Offset>[];
    for (var i = 0; i < (samples.length / 2); i++) {
      points.add(
        Offset(
          i / (samples.length / 2) * constraints.maxWidth,
          project(samples[i].toDouble(), _absMax, constraints.maxHeight),
        ),
      );
    }
    return points;
  }

  double project(double value, int max, double height) {
    final waveHeight = (value / max) * height;
    return waveHeight + _hightOffset * height;
  }
}

class _BuddycomButtonState extends State<BuddycomButton> {
  static const EventChannel _channel =
      EventChannel('com.morokoshi.audio.recorder');
  late StreamSubscription _streamSubscription;
  late Uint8List buffer;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const MorokoshiButton(),
          onLongPressStart: (details) {
            debugPrint("long press start");
            _streamSubscription = _channel.receiveBroadcastStream().listen(
              (event) {
                // debugPrint("event: $event");
                debugPrint(event.runtimeType.toString());
                setState(() {
                  buffer = event as Uint8List;
                });
                // debugPrint("event: $event");
              },
            );
          },
          onLongPressEnd: (details) {
            debugPrint("long press end");
            _streamSubscription.cancel();
          },
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CustomPaint(
              painter: WavePainter(
                samples: buffer,
                constraints: constraints,
              ),
            );
          },
        ),
      ],
    );
  }
}

class MorokoshiButton extends StatelessWidget {
  const MorokoshiButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      "aaa",
      style: Theme.of(context).textTheme.displayLarge,
    );
  }
}

class Buddycom extends StatelessWidget {
  const Buddycom({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final url = Uri(scheme: "ws", host: "54.193.15.138", port: 8080);
    // final channel = IOWebSocketChannel.connect(url);
    return /* StreamBuilder(
      stream: channel.stream,
      builder: ((context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        final a = snapshot.data!.toString();
        debugPrint(a);
        // channel.sink.add("Hello");
        return Text(a);
      }),
    ); */
        const BuddycomButton();
  }
}
