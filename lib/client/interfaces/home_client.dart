import 'package:flutter/material.dart';
import 'package:secure_way_client/client/interfaces/demande.dart';
import 'package:secure_way_client/client/interfaces/profile.dart';

class HomeClient extends StatefulWidget {
  const HomeClient({super.key});

  @override
  State<HomeClient> createState() => _HomeClientState();
}

class _HomeClientState extends State<HomeClient> {
  int index =0 ;
  List<Widget> interfaces = [
    Demande(),
    Profile()
  ];
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body:interfaces[index] ,
      bottomNavigationBar:BottomNavigationBar(
          onTap: (i){
           setState(() {
             index = i;

           });
            //     index = i;
          },
          currentIndex: index,
          items: [
            //0
            BottomNavigationBarItem(icon: Icon(Icons.car_crash),label:"demande"),
            //1
            BottomNavigationBarItem(icon: Icon(Icons.person),label:"profile")
          ]),
    );
  }
}

