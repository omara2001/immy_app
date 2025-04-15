<?php
require_once 'config.php';

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Method not allowed');
}

// Get JSON input
$data = json_decode(file_get_contents('php://input'), true);

// Validate input
if (!isset($data['name']) || !isset($data['email']) || !isset($data['password'])) {
    sendResponse(false, 'Missing required fields');
}

$name = $conn->real_escape_string(trim($data['name']));
$email = $conn->real_escape_string(trim($data['email']));
$password = $data['password'];

// Validate email
if (!isValidEmail($email)) {
    sendResponse(false, 'Invalid email format');
}

// Check if email already exists
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    sendResponse(false, 'Email already registered');
}
$stmt->close();

// Hash password
$hashed_password = password_hash($password, PASSWORD_DEFAULT);

// Insert new user
$stmt = $conn->prepare("INSERT INTO users (name, email, password, created_at) VALUES (?, ?, ?, NOW())");
$stmt->bind_param("sss", $name, $email, $hashed_password);

if ($stmt->execute()) {
    $user_id = $stmt->insert_id;
    
    // Generate token
    $token = generateToken($user_id, $email);
    
    // Return user data and token
    $user_data = [
        'id' => $user_id,
        'name' => $name,
        'email' => $email,
        'token' => $token
    ];
    
    sendResponse(true, 'Registration successful', $user_data);
} else {
    sendResponse(false, 'Registration failed: ' . $stmt->error);
}

$stmt->close();
$conn->close();
?>
