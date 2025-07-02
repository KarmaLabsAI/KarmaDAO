/**
 * Merkle Tree Helper Utilities
 * Stage 3: Token Sales Engine
 * 
 * Utilities for generating and managing Merkle trees for whitelist verification
 */

const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

/**
 * Generate a Merkle tree from a list of addresses
 * @param {string[]} addresses - Array of wallet addresses
 * @returns {MerkleTree} Generated Merkle tree
 */
function generateMerkleTree(addresses) {
    if (!addresses || addresses.length === 0) {
        throw new Error("Address list cannot be empty");
    }
    
    // Remove duplicates and convert to lowercase
    const uniqueAddresses = [...new Set(addresses.map(addr => addr.toLowerCase()))];
    
    // Generate leaves by hashing each address
    const leaves = uniqueAddresses.map(addr => keccak256(addr));
    
    // Create Merkle tree with sorted pairs for deterministic results
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    
    return tree;
}

/**
 * Generate a Merkle proof for a specific address
 * @param {MerkleTree} tree - The Merkle tree
 * @param {string} address - The address to generate proof for
 * @returns {string[]} Array of proof hashes
 */
function generateMerkleProof(tree, address) {
    if (!tree || !address) {
        throw new Error("Tree and address are required");
    }
    
    const normalizedAddress = address.toLowerCase();
    const leaf = keccak256(normalizedAddress);
    const proof = tree.getHexProof(leaf);
    
    return proof;
}

/**
 * Verify a Merkle proof for an address
 * @param {string[]} proof - Array of proof hashes
 * @param {string} address - The address to verify
 * @param {string} root - The Merkle root
 * @returns {boolean} True if proof is valid
 */
function verifyMerkleProof(proof, address, root) {
    if (!proof || !address || !root) {
        return false;
    }
    
    try {
        const normalizedAddress = address.toLowerCase();
        const leaf = keccak256(normalizedAddress);
        return MerkleTree.verify(proof, leaf, root, keccak256, { sortPairs: true });
    } catch (error) {
        console.error("Error verifying Merkle proof:", error);
        return false;
    }
}

/**
 * Generate whitelist data structure with tiers and allocations
 * @param {Object} config - Whitelist configuration
 * @param {Array} participants - Array of participant objects
 * @returns {Object} Whitelist data with Merkle trees per tier
 */
function generateTieredWhitelist(config, participants) {
    const tieredWhitelist = {};
    
    // Group participants by tier
    const participantsByTier = participants.reduce((acc, participant) => {
        const tier = participant.tier || 'PUBLIC';
        if (!acc[tier]) {
            acc[tier] = [];
        }
        acc[tier].push(participant.address);
        return acc;
    }, {});
    
    // Generate Merkle tree for each tier
    for (const [tier, addresses] of Object.entries(participantsByTier)) {
        if (addresses.length > 0) {
            const tree = generateMerkleTree(addresses);
            tieredWhitelist[tier] = {
                addresses: addresses,
                tree: tree,
                root: tree.getHexRoot(),
                count: addresses.length
            };
        }
    }
    
    return tieredWhitelist;
}

/**
 * Batch generate proofs for multiple addresses
 * @param {MerkleTree} tree - The Merkle tree
 * @param {string[]} addresses - Array of addresses
 * @returns {Object} Map of addresses to their proofs
 */
function batchGenerateProofs(tree, addresses) {
    const proofs = {};
    
    for (const address of addresses) {
        try {
            proofs[address.toLowerCase()] = generateMerkleProof(tree, address);
        } catch (error) {
            console.warn(`Failed to generate proof for ${address}:`, error.message);
            proofs[address.toLowerCase()] = null;
        }
    }
    
    return proofs;
}

/**
 * Validate whitelist configuration
 * @param {Object} config - Whitelist configuration
 * @param {Array} participants - Array of participants
 * @returns {Object} Validation result
 */
function validateWhitelistConfig(config, participants) {
    const validation = {
        valid: true,
        errors: [],
        warnings: [],
        stats: {}
    };
    
    // Validate participants
    if (!participants || participants.length === 0) {
        validation.valid = false;
        validation.errors.push("Participant list cannot be empty");
        return validation;
    }
    
    // Check for duplicate addresses
    const addresses = participants.map(p => p.address.toLowerCase());
    const uniqueAddresses = new Set(addresses);
    if (addresses.length !== uniqueAddresses.size) {
        validation.warnings.push("Duplicate addresses found in whitelist");
    }
    
    // Validate address format
    const invalidAddresses = participants.filter(p => 
        !p.address || !/^0x[a-fA-F0-9]{40}$/.test(p.address)
    );
    if (invalidAddresses.length > 0) {
        validation.valid = false;
        validation.errors.push(`Invalid address format for ${invalidAddresses.length} entries`);
    }
    
    // Check whitelist size limits
    if (config.maxWhitelistSize && participants.length > config.maxWhitelistSize) {
        validation.valid = false;
        validation.errors.push(`Whitelist size (${participants.length}) exceeds maximum (${config.maxWhitelistSize})`);
    }
    
    // Tier validation
    const tierCounts = {};
    participants.forEach(p => {
        const tier = p.tier || 'PUBLIC';
        tierCounts[tier] = (tierCounts[tier] || 0) + 1;
    });
    
    validation.stats = {
        totalParticipants: participants.length,
        uniqueAddresses: uniqueAddresses.size,
        tierBreakdown: tierCounts
    };
    
    return validation;
}

/**
 * Export whitelist data to various formats
 * @param {Object} whitelistData - Generated whitelist data
 * @param {string} format - Export format ('json', 'csv', 'merkle')
 * @returns {string} Formatted data
 */
function exportWhitelistData(whitelistData, format = 'json') {
    switch (format.toLowerCase()) {
        case 'json':
            return JSON.stringify(whitelistData, null, 2);
            
        case 'csv':
            const csvLines = ['Address,Tier,Proof'];
            for (const [tier, data] of Object.entries(whitelistData)) {
                for (const address of data.addresses) {
                    const proof = generateMerkleProof(data.tree, address);
                    csvLines.push(`${address},${tier},"${proof.join(',')}"`);
                }
            }
            return csvLines.join('\n');
            
        case 'merkle':
            const merkleData = {};
            for (const [tier, data] of Object.entries(whitelistData)) {
                merkleData[tier] = {
                    root: data.root,
                    count: data.count
                };
            }
            return JSON.stringify(merkleData, null, 2);
            
        default:
            throw new Error(`Unsupported export format: ${format}`);
    }
}

/**
 * Load whitelist from CSV file
 * @param {string} csvContent - CSV file content
 * @returns {Array} Array of participant objects
 */
function loadWhitelistFromCSV(csvContent) {
    const lines = csvContent.trim().split('\n');
    const headers = lines[0].toLowerCase().split(',');
    
    const addressIndex = headers.indexOf('address');
    const tierIndex = headers.indexOf('tier');
    
    if (addressIndex === -1) {
        throw new Error("CSV must contain 'address' column");
    }
    
    const participants = [];
    for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split(',');
        const participant = {
            address: values[addressIndex]?.trim()
        };
        
        if (tierIndex !== -1 && values[tierIndex]) {
            participant.tier = values[tierIndex].trim();
        }
        
        if (participant.address) {
            participants.push(participant);
        }
    }
    
    return participants;
}

/**
 * Generate sample whitelist for testing
 * @param {number} count - Number of addresses to generate
 * @param {Array} tiers - Available tiers
 * @returns {Array} Sample participant data
 */
function generateSampleWhitelist(count = 100, tiers = ['PARTNER', 'COMMUNITY', 'PUBLIC']) {
    const participants = [];
    
    for (let i = 0; i < count; i++) {
        // Generate random address
        const randomHex = Array.from({length: 40}, () => 
            Math.floor(Math.random() * 16).toString(16)
        ).join('');
        
        const address = `0x${randomHex}`;
        const tier = tiers[Math.floor(Math.random() * tiers.length)];
        
        participants.push({ address, tier });
    }
    
    return participants;
}

module.exports = {
    generateMerkleTree,
    generateMerkleProof,
    verifyMerkleProof,
    generateTieredWhitelist,
    batchGenerateProofs,
    validateWhitelistConfig,
    exportWhitelistData,
    loadWhitelistFromCSV,
    generateSampleWhitelist
}; 