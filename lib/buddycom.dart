import 'package:flutter/material.dart';
import "package:livekit_client/livekit_client.dart";

const url = "54.177.189.82";
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2ODc3MDUyMzMsImlzcyI6IkFQSVdIdHNrd3M0Zm5TYSIsImp0aSI6InRvbnlfc3RhcmsiLCJuYW1lIjoiVG9ueSBTdGFyayIsIm5iZiI6MTY1MTcwNTIzMywic3ViIjoidG9ueV9zdGFyayIsInZpZGVvIjp7InJvb20iOiJzdGFyay10b3dlciIsInJvb21Kb2luIjp0cnVlfX0.sUCElv-6CI2e3vI7TF4vSS0i_x0U4xms8bhGBYOq6BQ';

class Buddycom extends StatelessWidget {
  const Buddycom({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: () async {
        debugPrint("Connecting to $url");
        final room = await LiveKitClient.connect(url, token);
        debugPrint("Connected to $url 2");
        final localAudio = await LocalAudioTrack.create();
        debugPrint("Connecting to $url 3");
        await room.localParticipant?.publishAudioTrack(localAudio);
        return "OK";
      }(),
      builder: (context, snapshot) {
        return Text(snapshot.data ?? "Loading...");
      },
    );
  }
}
