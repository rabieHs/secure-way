import 'package:flutter/material.dart';

class Register extends StatelessWidget {
  const Register({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Padding(padding: EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center
          ,

          children: [

        Text('register',
          style: TextStyle(fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.blue
          ),),
          DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'user type',
              ),
          items: [
            DropdownMenuItem(child:Text("Client"),value: "client", ),
            DropdownMenuItem(child:Text("S.O.S"),value: "sos", ),
          ],onChanged: (value){
            print(value);
          },),

        TextField(
          decoration: InputDecoration(
            labelText: 'user name',
          ),
        ),TextField(
          decoration: InputDecoration(
            labelText: 'telephone',
          ),
        ),TextField(
          decoration: InputDecoration(
            labelText: 'email',
          ),
        ),TextField(
          decoration: InputDecoration(
            labelText: 'password',
          ),
        ),
        ElevatedButton(onPressed: (){}, child:Text('register')),
        InkWell(child: Text('login'),onTap: (){
          Navigator.pop(context);
        },)
      ],),) ,
    );
  } 
}
