# Modulo

La principal función de un módulo es definir componentes, que son, tipos y funciones, para que otros módulos, o el sistema, puedan usarlos (También debería poder definir datos).

Un módulo tiene una lista interna con todos los componentes que puede usar (una para tipos y otra para funciones), y accede a ellos usando el índice que ocupan en la lista, pero los que están definidos en ese módulo además tienen un nombre, que es el que otros módulos usan para referirse a ellos. Si la lista interna cambia pero los componentes mantienen el nombre, otro módulo puede seguir usándolos como si no hubieran cambios.

La lista interna tiene los componentes en el orden en que son definidos, por lo que los primeros siempre son los componentes importados de otros módulos y los últimos son los definidos en ese módulo.

Un módulo está compuesto de cuatro secciones.

## Dependencias

Declara los módulos externos necesarios para que el actual funcione y los componentes que se usarán de cada uno de ellos.

~~~
<module_count: varint>
{
  <module_name: string>
  <type_count: varint>
  {
    <type_name: string>
    <field_count: varint>
    <field_name: string>[field_count]
  }[byte_count]
  <func_count: varint>
  {
    <func_name: string>
    <param_count: varint>
    <result_count: varint>
  }[func_count]
}[module_count]
~~~

## Tipos

Los tipos en Cobre son equivalentes a lo que en otros contextos se conoce como estructuras o records.

~~~
<type_count: varint>
{
  <type_name: string>
  <field_count: varint>
  {
    <field_name: string>
    <field_type: varint>
  }[field_count]
}[type_count]
~~~

## Funciones

Solo los prototipos de las funciones, porque el código de algunas es recursivo, y no puedo leerlo hasta no saber el prototipo de todas las funciones.

~~~
<func_count: varint>
{
  <func_name: string>

  <param_count: varint>
  <param_reg: varint>[param_count]

  <result_count: varint>
  <result_reg: varint>[result_count]

  <register_count: varint>
  <register_type: varint>[register_count]
}[func_count]
~~~

## Código

Se escribe separado del prototipo de las funciones porque se necesitan todas las definiciones para poder entender el código. No hace falta escribir el número de bloques porque ya se sabe el número de funciones. El tamaño de cada bloque se indica en número de instrucciones, no de bytes.

~~~
{
  <code_length: varint>
  <instruction>[code_length]
}[func_count]
~~~

## Constantes

Por ahora, las constantes solo se pueden usar con la instrucción *cns*, no se puede acceder a constantes de otros módulos pero me gustaría que en el futuro se pudiera.

Cada constante tiene un tipo, y el contenido depende del tipo. Si el tipo de la constante es importado y no tiene ningún campo definido, entonces el contenido de la constante es un array de bytes, cuya longigtud está especificada en el primer byte del contenido. Si en cambio el tipo tiene campos definidos, el contenido es una lista de referencias a otras constantes cuya longitud número de campos del tipo.

Si la declaración del tipo en el módulo tiene menos campos que su definición en su módulo original, no se puede crear como constante, ya que todos los campos deben tener un valor definido.

~~~
<const_count: byte>
{
  <type: byte>
  {
    <byte_count: byte>
    <bytes: byte>[byte_count]
  }[if type.field_count=0]
  {
    <field_value: byte>[type.field_count]
  }[if type.field_count>0]
}[const_count]
~~~


