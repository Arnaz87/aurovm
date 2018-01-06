
lazy val commonSettings = Seq(
  scalaVersion := "2.12.4"
)


// JVM Only
lazy val bindump = (project in file("bindump")).
  settings(commonSettings: _*)
  


lazy val cobre = (crossProject in file("cobre")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/"
  )
lazy val cobreJS = cobre.js
lazy val cobreJVM = cobre.jvm.dependsOn(bindump)



lazy val cu = (crossProject in file("cu")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/",
    libraryDependencies ++= Seq("com.lihaoyi" %%% "fastparse" % "1.0.0")
  ).
  dependsOn(cobre)
lazy val cuJS = cu.js
lazy val cuJVM = cu.jvm



lazy val js = (crossProject in file("js")).
  settings(commonSettings: _*).
  settings(
    scalaSource in Compile := baseDirectory.value / "../shared/"
  ).
  dependsOn(cobre)
lazy val jsJS = js.js
lazy val jsJVM = js.jvm.dependsOn(cuJVM)


// JS Only
lazy val web = (project in file("web")).
  enablePlugins(ScalaJSPlugin).
  settings(commonSettings: _*).
  settings(
    // Sólo si tiene main, si es solo una librería esto no se pone
    //scalaJSUseMainModuleInitializer := true
  ).
  dependsOn(cuJS, jsJS)
