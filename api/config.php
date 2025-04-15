<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_NAME', 'immy_app');

// Create database connection
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Set headers for API responses
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Helper function to generate JSON response
function sendResponse($status, $message, $data = null) {
    $response = [
        'status' => $status,
        'message' => $message
    ];
    
    if ($data !== null) {
        $response['data'] = $data;
    }
    
    echo json_encode($response);
    exit();
}

// Helper function to validate email
function isValidEmail($email) {
    return filter_var($email, FILTER_VALIDATE_EMAIL);
}

// Helper function to generate JWT token
function generateToken($user_id, $email) {
    $secret_key = "immy_app_secret_key"; // In production, use a more secure key
    $issued_at = time();
    $expiration = $issued_at + (60 * 60 * 24); // Token valid for 24 hours
    
    $payload = [
        'iat' => $issued_at,
        'exp' => $expiration,
        'user_id' => $user_id,
        'email' => $email
    ];
    
    // For simplicity, we're using a basic encoding method
    // In production, use a proper JWT library
    return base64_encode(json_encode($payload));
}

// Helper function to verify token
function verifyToken($token) {
    try {
        $decoded = json_decode(base64_decode($token), true);
        
        if (!$decoded || !isset($decoded['exp']) || !isset($decoded['user_id'])) {
            return false;
        }
        
        // Check if token is expired
        if ($decoded['exp'] < time()) {
            return false;
        }
        
        return $decoded;
    } catch (Exception $e) {
        return false;
    }
}
?>
