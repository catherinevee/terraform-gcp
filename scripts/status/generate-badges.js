const fs = require('fs');
const path = require('path');

function generateBadge(status) {
    const configs = {
        live: { color: '#28a745', text: 'LIVE' },
        unalive: { color: '#dc3545', text: 'UNALIVE' },
        partial: { color: '#ffc107', text: 'PARTIAL' }
    };
    
    const config = configs[status] || configs.unalive;
    const textWidth = config.text.length * 6 + 10;
    const labelWidth = 9 * 6 + 10; // "Deployment"
    const totalWidth = labelWidth + textWidth;
    
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + totalWidth + '" height="20">' +
        '<linearGradient id="b" x2="0" y2="100%">' +
        '<stop offset="0" stop-color="#bbb" stop-opacity=".1"/>' +
        '<stop offset="1" stop-opacity=".1"/>' +
        '</linearGradient>' +
        '<mask id="a">' +
        '<rect width="' + totalWidth + '" height="20" rx="3" fill="#fff"/>' +
        '</mask>' +
        '<g mask="url(#a)">' +
        '<path fill="#555" d="M0 0h' + labelWidth + 'v20H0z"/>' +
        '<path fill="' + config.color + '" d="M' + labelWidth + ' 0h' + textWidth + 'v20H' + labelWidth + 'z"/>' +
        '<path fill="url(#b)" d="M0 0h' + totalWidth + 'v20H0z"/>' +
        '</g>' +
        '<g fill="#ffffff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">' +
        '<text x="' + (labelWidth / 2) + '" y="15" fill="#010101" fill-opacity=".3">Deployment</text>' +
        '<text x="' + (labelWidth / 2) + '" y="14">Deployment</text>' +
        '<text x="' + (labelWidth + textWidth / 2) + '" y="15" fill="#010101" fill-opacity=".3">' + config.text + '</text>' +
        '<text x="' + (labelWidth + textWidth / 2) + '" y="14">' + config.text + '</text>' +
        '</g>' +
        '</svg>';
}

// Create docs directory
const outputDir = path.join(__dirname, '..', '..', 'docs', 'status');
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

// Generate badges
['live', 'unalive', 'partial'].forEach(status => {
    const svg = generateBadge(status);
    const filePath = path.join(outputDir, status + '.svg');
    fs.writeFileSync(filePath, svg);
    console.log('Generated ' + status + '.svg');
});

console.log('Badge generation completed!');
