
// Las fuentes no manejadas (unamaged) son fuentes creadas manualmente,
// a diferencia de las manejadas (managed) que son creadas automáticamente.
// Compile es el scope.
//unmanagedSourceDirectories in Compile += baseDirectory.value / "src/machine"

import com.typesafe.sbt.SbtStartScript

//Seq(SbtStartScript.startScriptForClassesSettings: _*)

lazy val commonSettings = Seq(
  scalaVersion := "2.11.8"
) ++ Seq(SbtStartScript.startScriptForClassesSettings: _*)

lazy val bindump = (project in file("bindump")).
  settings(commonSettings: _*)

lazy val codegen = (project in file("codegen")).
  settings(commonSettings: _*).
  dependsOn(sexpr, bindump)

lazy val sexpr = (project in file("sexpr")).
  settings(commonSettings: _*)

lazy val lua = (project in file("lua")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(codegen)

lazy val cu = (project in file("cu")).
  settings(commonSettings: _*).
  settings(
    libraryDependencies ++= Seq("com.lihaoyi" %% "fastparse" % "0.3.7")
  ).
  dependsOn(codegen)
