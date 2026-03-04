<?php
$servername = getenv("MYSQL_HOST") ?: "mysql";
$username = getenv("MYSQL_USER") ?: "root";
$password = getenv("MYSQL_PASSWORD");
$database = getenv("MYSQL_DATABASE") ?: "meubanco";

if ($password === false) {
    $password = "";
}

// Criar conexão


$link = new mysqli($servername, $username, $password, $database);

/* check connection */
if (mysqli_connect_errno()) {
    printf("Connect failed: %s\n", mysqli_connect_error());
    exit();
}

?>
