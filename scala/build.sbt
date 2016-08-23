
// Las fuentes no manejadas (unamaged) son fuentes creadas manualmente,
// a diferencia de las manejadas (managed) que son creadas automáticamente.
// Compile es el scope.
//unmanagedSourceDirectories in Compile += baseDirectory.value / "src/machine"

lazy val commonSettings = Seq(
  scalaVersion := "2.11.8"
)

lazy val root = (project in file(".")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "machine"
  )

lazy val codegen = (project in file("codegen")).
  settings(commonSettings: _*).
  dependsOn(root)

lazy val lua = (project in file("lua")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(root, codegen)

lazy val sexpr = (project in file("sexpr")).
  settings(commonSettings: _*)

// Para correr lua, se usa lua/run