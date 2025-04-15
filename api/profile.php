<?php
require_once 'config.php';

// Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendResponse(false, 'Method not allowed');
}

// Check for authorization header
$headers = getallheaders();
if (!isset($headers['Authorization'])) {
    sendResponse(false, 'Authorization required');
}

// Extract token
$token = str_replace('Bearer ', '', $headers['Authorization']);

// Verify token
$decoded = verifyToken($token);
if (!$decoded) {
    sendResponse(false, 'Invalid or expired token');
}

$user_id = $decoded['user_id'];

// Get user profile
$stmt = $conn->prepare("SELECT id, name, email, created_at FROM users WHERE id = ?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    sendResponse(false, 'User not found');
}

$user = $result->fetch_assoc();
$stmt->close();

// Get user's child data if available
$stmt = $conn->prepare("SELECT id, name, age, interests FROM children WHERE user_id = ?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

$children = [];
while ($child = $result->fetch_assoc()) {
    $children[] = $child;
}
$stmt->close();

// Return user profile data
$profile_data = [
    'user' => $user,
    'children' => $children
];

sendResponse(true, 'Profile retrieved successfully', $profile_data);

$conn->close();
?>
