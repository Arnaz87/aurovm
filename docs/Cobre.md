# Cobre

Estructura de la máquina virtual.

# Objeto

Un Objeto es un contenedor de datos, cuya estructura está definida por un Struct.

# Structs

El Struct está organizado por un número finito de campos, accesibles con un índice entero desde 0 hasta el tamaño del Struct menos 1, y cada campo tiene un Tipo. Un array de tipos es suficiente para representar un Struct, porque incluye el tamaño y el tipo de cada campo.

# Función

Lo más importante de una función es el código, es una sequencia de instrucciones que la máquina virtual ejecuta.

El código de una función asume la existencia de un objeto implícito que representa los registros (Se usa un objeto porque vienen con seguridad de tipos incluida). También se usa un objeto por el cual se comunican la función y quien invoca la función. Es este objeto el que se usa para pasar argumentos y devolver valores. Se puede acceder a este objeto por uno de los registros de la función, y con otro registro también se puede acceder al módulo al que pertenece la función.

Un código externo que quiere interactuar con una función, la ve como si fuera el objeto de argumentos, no puede ver los registros ni el código. Cambiar los campos de dicho objeto es la manera en l

# Instrucciones

Cobre tiene un conjunto de instrucciones muy reducido y básico:

- cpy: copia un registro a otro
- get: copia el contenido de un campo de un objeto a un registro
- set: copia el contenido de un registro a un campo de un objeto
- new: crea un objeto del tipo del registro en que se guardará
- jmp: salta a la instrucción indicada
- jif: salta a la instrucción indicada si la condición es verdadera
- end: termina la ejecución de la función

Instrucciónes temporales o no escenciales:

- lbl: marca la instrucción como destinación de salto
- ifn: salta a la instrucción indicada si la condicion es falsa
- nop: no hace nada
- cast: intenta copiar un registro a otro de diferente tipo

Algo interesante de este conjunto de instrucciones es que no se incluyen operaciones aritméticas o por el estilo.

Una de las razones es que ayuda a simplificar la especificación de Cobre, y fácilita una implementación muy rápida y pequeña, delegando por lo tanto las operaciones básicas a la librería estándar.

Otra razón y más importante es que diferentes lenguajes tienen diferentes semánticas en cuanto a operaciones básicas, y Cobre a diferencia de otras máquinas virtuales no está diseñada con ningún lenguaje en específico en mente.

Lo más importante de esta decisión es que aplica presión a los desarrolladores de Cobre en diseñar un método simple y eficiente para ejecutar operaciones básicas, lo que beneficiará a todos los lenguajes que se implementen sobre Cobre.

# Modelo de Datos

```





```
