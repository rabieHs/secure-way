import 'package:flutter/material.dart';
import 'package:secure_way_client/authentification/interfaces/register.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 20,
       //crossAxisAlignment:CrossAxisAlignment.center,
        mainAxisAlignment:MainAxisAlignment.center ,
        children: [
          Text("Login",style: TextStyle(fontSize: 50,fontWeight:FontWeight.bold,color: Colors.blue),),
          TextField(
            decoration:InputDecoration(
              labelText: "email",
             // prefixIcon: Icon(Icons.email)
            ) ,
          ),
          TextField(
            obscureText: true,
            decoration:InputDecoration(
              labelText: "password",
              // prefixIcon: Icon(Icons.email)
            ) ,
          ),

          ElevatedButton(onPressed: (){}, child:
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

            Icon(Icons.arrow_forward_ios),
            Text("Login")
          ],
          )
          ),

          InkWell(
            onTap: (){
            Navigator.push(context, MaterialPageRoute(builder: (_)=>Register()));
            },

            child: Text("You don't  have an account? Register",style: TextStyle(color: Colors.blue),),
          )

      ],),
    ),
    ) ;
  }}
