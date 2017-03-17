# Modulo

La principal función de un módulo es definir componentes, que son, tipos y funciones, para que otros módulos, o el sistema, puedan usarlos. No se exportan datos porque las funciones de un módulo tienen acceso a sus datos.

Un módulo tiene una lista interna con todos los componentes que puede usar (una para tipos, otra para funciones, y una extra para constantes), y accede a ellos usando el índice que ocupan en la lista, pero los que están definidos en ese módulo además tienen un nombre, que es el que otros módulos usan para referirse a ellos. Si la lista interna cambia pero los componentes mantienen el nombre, otro módulo puede seguir usándolos como si no hubieran cambios.

La lista interna tiene los componentes en el orden en que son definidos, por lo que los primeros siempre son los componentes importados de otros módulos y los últimos son los definidos en el módulo.

Un módulo está compuesto de varias secciones.

## Contadores

Indica el tamaño de cada una de las tablas del módulo.

~~~
<type_count: int>
<rout_count: int>
<const_count: int>
~~~

## Exports

Indica qué tipos exporta el módulo y con qué nombre

~~~
<exported_type_count: int>
{
  <type: type_index>
  <name: string>
}[exported_type_count]

<exported_rout_count: int>
{
  <rout: rout_index>
  <name: string>
}[exported_rout_count]
~~~

## Parámetros

Un módulo puede recibir parámetros, estos se guardan en la tabla de valores. Es un poco extraño que un módulo reciba parámetros valores pero solo devuelva tipos y rutinas. Esto es porque al importar un módulo, se le debe dar la posibilidad de ejecutar código con valores de entrada arbitrarios, pero hay que recordar que lo que otros módulos esperan son tipos y funciones para poder ser usados en sus definiciones, no valores.

~~~
<param_count: int>
<param_type: type_index>[param_count]
~~~

## Rutinas

El prototipo de todas las rutinas del módulo

~~~
{
  <in_count: int>
  <in_type: type_index>[in_count]

  <out_count: int>
  <out_type: type_index>[out_count]
}[rout_count]
~~~

## Dependencias

Declara los módulos externos necesarios para que el actual funcione y los componentes que se usarán de cada uno de ellos. Los módulos pueden recibir valores como parámetros, y exportan tipos y funciones, pero no exportan valores.

~~~
<module_count: varint>
{
  <module_name: string>

  <param_count: int>
  <param: const_index>[param_count]

  <type_count: int>
  <type_name: string>[type_count]

  <rout_count: varint>
  <rout_name: string>[rout_count]
}[module_count]
~~~

## Uso de tipos

Algunas constantes pueden ser tipos, y esta sección puede seleccionar algunas de ellas para ser usadas como tipos en el módulo, además de constantes.

~~~
<type_use_count: int>
<const: const_index>[type_use_count]
~~~

## Tipos

Los tipos en Cobre usualmente son equivalentes a lo que en otros contextos se conoce como estructuras o records. Solo el módulo en el que un tipo es definido tiene acceso a los campos, para otros módulos los tipos siempre son opacos, pero se pueden exportar rutinas getters y setters.

~~~
<type_count: int>
{
  <field_count: int>
  <field_type: type_index>[field_count]
}[type_count]
~~~

## Uso de funciones

Algunas constantes pueden ser rutinas, y esta sección puede seleccionar algunas de ellas para ser usadas como rutinas en el módulo e indican el prototipo.

~~~
<type_use_count: int>
<const: const_index>[type_use_count]
~~~

## Rutinas

Los registros de una función están compuestos primero por las salidas, luego las entradas, y luego los especiales. Las salidas y entradas están en la sección de declaraciones.

~~~
<rout_count: int>
{
  <reg_count: int>
  <reg_type: type_index>[reg_count]

  <code_length: varint>
  <instruction>[code_length]
}[rout_count]
~~~

## Constantes

Cada entrada en esta sección tiene trs partes: el formato, el tipo y los datos. Los datos dependen del formato. Si el formato es menor a 16, indica uno de los formatos especiales que se explican más abajo. Si es igual o mayor a 16, indica una función en la lista de funciones con índice-16. El tipo se omite ya que lo indica la función. Los datos son los argumentos de la función, cada uno se representa como un índice-1 en la tabla de constantes. Cada salida de la función cuenta como una constante.

Los formatos especiales son:

- null: Ningún valor. No sé en qué contexto puede ser útil
- varint: Entero positivo de número variable de bits
- byte: Entero positivo de 8 bits
- int64: Entero con signo de 64 bits
- float64: Coma flotante de 64 bits
- binary: Empieza con un varint indicando el tamaño, seguido de ese número de bytes, incluyendo 0
- array: Empieza con un varint indicando el tamaño, seguido de ese número de índices a la tabla de constantes, representados como varints.
- type: Índice en la tabla de tipos representado como varint.
- proc: Índice en la tabla de funciones representado como varint.

~~~
<const_count: int>
{
  <format: int>
  {
    <type: type_index>

    <value: int>[if format=varint,type,proc]
    <value: byte>[if format=byte]
    {<value: byte>[4]}[if format=int64,float64]
    {
      <byte_count: int>
      <byte: byte>[byte_count]
    }[if format=binary]
    {
      <val_count: int>
      <val: const_index>[val_count]
    }[if format=array]
    <value: type_index>[if format=type]
    <value: rout_index>[if format=rout]
  }[if format<16]
  {
    <value: const_index>[type[format-16].in_count]
  }[if format>=16]
}[const_count]
~~~


