import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import "dart:async";
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

/// だいたいここからのコピペ
/// https://zenn.dev/pressedkonbu/books/flutter-reverse-lookup-dictionary/viewer/010-audi-streamer
class WavePainter extends CustomPainter {
  WavePainter({
    required this.samples,
    required this.constraints,
  });

  BoxConstraints constraints;
  Uint8List samples;
  static const color = Colors.blue;

  final uIntMax = pow(2, 8);

  @override
  void paint(Canvas canvas, Size size) {
    // 色、太さ、塗り潰しの有無などを指定
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 得られたデータをオフセットのリストに変換する
    // やっていることは決められた範囲で等間隔に点を並べているだけ
    final points = toPoints(samples).toList();

    // addPolygon で path をつくり drawPath でグラフを表現する
    final path = Path()..addPolygon(points, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(oldDelegate) => true;

  // 得られたデータを等間隔に並べていく
  Iterable<Offset> toPoints(Uint8List samples) sync* {
    final length = samples.length;
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;
    for (final sample in samples.asMap().entries) {
      final y = sample.value / uIntMax * height;
      final x = sample.key / length * width;
      yield Offset(x, y);
    }
  }
}

class _BuddycomButtonState extends State<BuddycomButton> {
  static const EventChannel _recordChannel =
      EventChannel("com.morokoshi.audio.recorder");
  static const MethodChannel _playChannel =
      MethodChannel("com.morokoshi.audio.player");
  late StreamSubscription _streamSubscription;
  Uint8List buffer = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
  List<Uint8List> playList = [];
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
            _streamSubscription =
                _recordChannel.receiveBroadcastStream().listen(
              (event) {
                // debugPrint("event: $event");
                debugPrint(event.runtimeType.toString());
                setState(() {
                  buffer = event as Uint8List;
                  playList.add(buffer);
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
        ElevatedButton(
          onPressed: () async {
            await _playChannel.invokeMethod("ready");
            for (final play in playList) {
              await _playChannel.invokeMethod("play", {"byte": play});
            }
          },
          child: const Text("play"),
        ),
        /* LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CustomPaint(
              painter: WavePainter(
                samples: buffer,
                constraints: constraints,
              ),
            );
          },
        ), */
        /* CustomPaint(
          painter: WavePainter(
            samples: buffer,
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
          ),
          willChange : true,
          size:const Size(200,200)
        ) */
        // const WavePainter2Test(),
        // const WavePainter1Test(),
        /* LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CustomPaint(
              size: Size(200, constraints.maxWidth),
              painter: WavePainter(
                samples: buffer,
                constraints: BoxConstraints(maxWidth:constraints.maxWidth,maxHeight:200),
              ),
            );
          },
        ), */
        CustomPaint(
          size: const Size(200, 200),
          painter: WavePainter(
            samples: buffer,
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          ),
        ),
      ],
    );
  }
}

class WavePainter2Test extends StatefulWidget {
  const WavePainter2Test({Key? key}) : super(key: key);
  @override
  State<WavePainter2Test> createState() => _WavePainter2TestState();
}

class _WavePainter2TestState extends State<WavePainter2Test> {
  var buffer = [0.0, 0.0, 0.0, 0.0];
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      buffer = List.generate(100, (index) => Random().nextDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: WavePainter2(
        samples: buffer,
        color: Colors.blue,
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
      ),
    );
  }
}

class WavePainter1Test extends StatefulWidget {
  const WavePainter1Test({Key? key}) : super(key: key);
  @override
  State<WavePainter1Test> createState() => _WavePainter1TestState();
}

class _WavePainter1TestState extends State<WavePainter1Test> {
  var buffer = Uint8List.fromList([1, 2, 3, 4]);
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        buffer = Uint8List.fromList(
          List.generate(100, (index) => Random().nextInt(256)),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: WavePainter(
        samples: buffer,
        // color: Colors.blue,
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
      ),
    );
  }
}

class WavePainter2 extends CustomPainter {
  WavePainter2({
    required this.samples,
    required this.color,
    required this.constraints,
  });

  BoxConstraints constraints;
  List<double> samples;
  Color color;

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
  bool shouldRepaint(oldPainting) => true;

  // 得られたデータを等間隔に並べていく
  List<Offset> toPoints(List<double> samples) {
    final points = <Offset>[];
    for (var i = 0; i < (samples.length / 2); i++) {
      points.add(
        Offset(
          i / (samples.length / 2) * constraints.maxWidth,
          project(samples[i], _absMax, constraints.maxHeight),
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
