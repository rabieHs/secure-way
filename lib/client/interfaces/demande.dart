import 'package:flutter/material.dart';

class Demande extends StatefulWidget {
  const Demande({super.key});

  @override
  State<Demande> createState() => _DemandeState();
}

class _DemandeState extends State<Demande> {
  List<String>list =[];
  @override
  Widget build(BuildContext context) {


    return  Scaffold(

      floatingActionButton: FloatingActionButton(onPressed: (){
     showModalBottomSheet(context: context, builder: (context){
       return Container(
         width: double.infinity,
        child: Column(
          children: [
            //

          ],
        ),
       );
     });
      },child: Icon(Icons.add),),
      body:Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context,index){
          return

          Card(
            elevation: 1,
            child: Container(
              padding:EdgeInsets.all(16) ,
            child:Column(
              spacing: 10,
              children: [

            Row(
              spacing: 15,
              children: [
              Text("Demande ID:",style: TextStyle(fontWeight: FontWeight.bold),),
              Text("1234567",style: TextStyle(color: Colors.grey),),
            ],),
                Row(
                  spacing: 15,
                  children: [
                  Text("Date:",style: TextStyle(fontWeight: FontWeight.bold),),
                  Text("12;33",style: TextStyle(color: Colors.grey),),
                ],), Row(
                  spacing: 15,
                  children: [
                    Text("Time:",style: TextStyle(fontWeight: FontWeight.bold),),
                    Text("12-03-1234",style: TextStyle(color: Colors.grey),),
                  ],), Row(
                  spacing: 15,
                  children: [
                    Text("Location:",style: TextStyle(fontWeight: FontWeight.bold),),
                    Text("sidi mansour 13423",style: TextStyle(color: Colors.grey),),
                  ],), Row(
                  spacing: 15,
                  children: [
                    Text("Status:",style: TextStyle(fontWeight: FontWeight.bold),),
                    Text("wating",style: TextStyle(color: Colors.orange),),
                  ],),

              ],
            ) ,
              height: 180,
              width: double.infinity ,

            ),
          );

        })



      ) ,
    );
  }
}
