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

// Get child ID from query parameter
$child_id = isset($_GET['child_id']) ? intval($_GET['child_id']) : 0;

// Validate child belongs to user
if ($child_id > 0) {
    $stmt = $conn->prepare("SELECT id FROM children WHERE id = ? AND user_id = ?");
    $stmt->bind_param("ii", $child_id, $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        sendResponse(false, 'Child not found or not authorized');
    }
    $stmt->close();
} else {
    // Get the first child if no specific child is requested
    $stmt = $conn->prepare("SELECT id FROM children WHERE user_id = ? LIMIT 1");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        sendResponse(false, 'No children found for this user');
    }
    
    $child = $result->fetch_assoc();
    $child_id = $child['id'];
    $stmt->close();
}

// Get coach data
$coach_data = [
    'engagement' => 87,
    'new_skills' => 5,
    'current_activity' => [
        'title' => 'Solar System Craft',
        'description' => 'Create a model solar system using household items to build on Emma\'s space interest.'
    ],
    'milestones' => [
        [
            'id' => 1,
            'title' => 'Advanced Number Recognition',
            'description' => 'Successfully counted to 20 without help',
            'icon' => 'star'
        ],
        [
            'id' => 2,
            'title' => 'Scientific Curiosity',
            'description' => 'Growing interest in space and planets',
            'icon' => 'science'
        ]
    ],
    'recommended_activities' => [
        [
            'id' => 1,
            'title' => 'Solar System Craft',
            'description' => 'Create a model solar system using household items to build on Emma\'s space interest.',
            'icon' => 'rocket'
        ],
        [
            'id' => 2,
            'title' => 'Number Scavenger Hunt',
            'description' => 'Find and count objects around the house to practice numbers up to 20.',
            'icon' => 'numbers'
        ]
    ]
];

sendResponse(true, 'Coach data retrieved successfully', $coach_data);

$conn->close();
?>
