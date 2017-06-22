# SafeTSA

*[2017-06-22 08:18]*

https://en.wikipedia.org/wiki/SafeTSA

Me llama mucho la atención esta representación para Cobre, SSA es mejor para compiladores y muchos ya lo usan de todos modos (como el JVM), así que se puede ahorrar parte de trabajo si ya está hecho en el formato, potencialmente puede ocupar menos espacio porque todos los registros son creados implícitamente, y es garantizado que todas las instrucciones usan los tipos correctos.

La mayor desventaja es la gran cantidad de registros que se crean, lo cual no es problema para un compilador pero sí para un intérprete, y también lo es para la representación porque hay más posibilidades de que el índice de un registro sea grande, y por lo tanto ocupa más espacio (porque se usan varints). El otro problema es que el tipo de los registros no está marcado explícitamente, y una implementación debe pasar por el código y revisar el tipo de cada operación ejecutada para saber el tipo del resultado, el cual en consecuencia define el tipo del registro implícito.

Escribiendo esto me doy cuenta de que talves SafeTSA no sea tan positivo como pensaba, pero igual me sigue llamando la atención.