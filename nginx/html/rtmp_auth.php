<?php
$username = $_POST["n"];
$password = $_POST["p"];

$valid_users = array("sfc" => "8c1b69ba-75ad-4606-855f-65e9af6b0946", "portable" => "9b52b7c8-0d43-4589-b229-73a8a6a5e4af");

if ($valid_users[$username] == $password) {
  http_response_code(201); # return 201 "Created"
} else {
  http_response_code(404); # return 404 "Not Found"
}
?>
