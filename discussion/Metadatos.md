# Metadatos

## source map

Cada nodo source map es un archivo fuente. Diferentes archivos fuentes deben estar definidos en diferentes nodos.

- Archivo Fuente
- Componentes: Una sola lista de átomos, cada cuatro átomos describen un componente
  - Tipo de componente (Modulo, Tipo, Rutina, Valor)
  - Índice del componente
  - Línea en la fuente
  - Columna en la fuente
- Code
  - Índice del bloque
  - Registros: Cada tres átomos describen un registro
    - índice, línea, columna
  - Instrucciones: Cada tres átomos describen una instrucción
    - índice, línea, columna

~~~
("file" filename)
(components (kind file index line column name?)* )
("code"
  (block_index
    ("regs" (index name line column?)*)
    ("inst" (index line column?)*)
  )*
)
~~~

## structure

Contiene una lista de rutinas con la estructura de su código.

~~~
( rutine_index
  ( type
    ( regs* ) ; Variables declaradas en este bloque
    {match type
    block:
      first_inst
      last_inst
    if:
      cond_inst
      code_lbl
      (else_lbl else_block_lbl)*
      end_lbl
    while:
      cond_lbl
      code_lbl
      end_lbl
    do while:
      code_lbl
      cond_inst
      end_lbl
    c for:
      init_inst
      cond_lbl
      inc_inst
      end_lbl
    for in:
      cond_lbl
      code_lbl
      end_lbl
    }
  )*
)*
~~~
