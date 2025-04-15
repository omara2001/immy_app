<?php
require_once 'config.php';

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Method not allowed');
}

// Get JSON input
$data = json_decode(file_get_contents('php://input'), true);

// Validate input
if (!isset($data['email']) || !isset($data['password'])) {
    sendResponse(false, 'Missing required fields');
}

$email = $conn->real_escape_string(trim($data['email']));
$password = $data['password'];

// Get user by email
$stmt = $conn->prepare("SELECT id, name, email, password FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    sendResponse(false, 'Invalid email or password');
}

$user = $result->fetch_assoc();
$stmt->close();

// Verify password
if (!password_verify($password, $user['password'])) {
    sendResponse(false, 'Invalid email or password');
}

// Generate token
$token = generateToken($user['id'], $user['email']);

// Return user data and token
$user_data = [
    'id' => $user['id'],
    'name' => $user['name'],
    'email' => $user['email'],
    'token' => $token
];

sendResponse(true, 'Login successful', $user_data);

$conn->close();
?>
