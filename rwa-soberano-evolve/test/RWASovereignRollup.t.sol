// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/RWASovereignRollup.sol";
import "../src/RWAToken.sol";

contract RWASovereignRollupTest is Test {
    RWASovereignRollup public rollup;
    RWAToken public rwaToken;
    address public owner;
    address public user;

    bytes32 constant TEST_DOCUMENT_HASH = keccak256("test document");
    string constant TEST_DOCUMENT_URI = "ipfs://QmTest";
    string constant TEST_DOCUMENT_TYPE = "Legal Document";

    event RollupBlockCommitted(
        uint256 indexed blockNumber,
        bytes32 indexed stateRoot,
        bytes32 indexed daHash,
        address aggregator
    );

    event TokenizationRequested(
        address indexed requester,
        uint256 amount,
        bytes32 documentHash,
        uint256 timestamp
    );

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");

        rollup = new RWASovereignRollup();
        rwaToken = new RWAToken("ipfs://QmBase/");

        // Set RWAToken in rollup
        rollup.setRWAToken(payable(address(rwaToken)));
    }

    function test_Constructor() public {
        RWASovereignRollup newRollup = new RWASovereignRollup();
        assertEq(newRollup.owner(), owner);
        assertNotEq(address(newRollup.documentRegistry()), address(0)); // DocumentRegistry is created in constructor
        assertEq(newRollup.blockNumber(), 1);
    }

    function test_SetRWAToken() public {
        RWASovereignRollup newRollup = new RWASovereignRollup();
        address tokenAddress = makeAddr("token");

        vm.prank(owner);
        newRollup.setRWAToken(payable(tokenAddress));

        assertEq(address(newRollup.rwaToken()), tokenAddress);
    }

    function test_SetRWAToken_RevertIfAlreadySet() public {
        vm.expectRevert("RWAToken already set");
        rollup.setRWAToken(payable(makeAddr("anotherToken")));
    }

    function test_SetRWAToken_RevertIfZeroAddress() public {
        RWASovereignRollup newRollup = new RWASovereignRollup();

        vm.prank(owner);
        vm.expectRevert("Invalid token address");
        newRollup.setRWAToken(payable(address(0)));
    }

    function test_SetRWAToken_RevertIfNotOwner() public {
        RWASovereignRollup newRollup = new RWASovereignRollup();

        vm.prank(user);
        vm.expectRevert();
        newRollup.setRWAToken(payable(address(rwaToken)));
    }

    function test_Registry_ReturnsDocumentRegistry() public {
        assertEq(rollup.registry(), address(rollup.documentRegistry()));
    }

    function test_CommitBlock() public {
        bytes32 stateRoot = keccak256("test state root");
        bytes32 daHash = keccak256("test da hash");

        vm.expectEmit(true, true, true, true);
        emit RollupBlockCommitted(1, stateRoot, daHash, owner);

        vm.prank(owner);
        rollup.commitBlock(stateRoot, daHash);

        assertEq(rollup.lastStateRoot(), stateRoot);
        assertEq(rollup.blockNumber(), 2);

        (bytes32 storedStateRoot, bytes32 storedDaHash, uint256 timestamp, address aggregator) = rollup.blocks(1);
        assertEq(storedStateRoot, stateRoot);
        assertEq(storedDaHash, daHash);
        assertEq(aggregator, owner);
        assertGt(timestamp, 0);
    }

    function test_CommitBlock_RevertIfNotOwner() public {
        bytes32 stateRoot = keccak256("test state root");
        bytes32 daHash = keccak256("test da hash");

        vm.prank(user);
        vm.expectRevert();
        rollup.commitBlock(stateRoot, daHash);
    }

    function test_RequestTokenization() public {
        uint256 assetId = 1;
        uint256 amount = 100;

        uint256 expectedRequestId = uint256(keccak256(abi.encodePacked(user, assetId, amount, block.timestamp)));

        vm.expectEmit(true, true, true, true);
        emit TokenizationRequested(user, amount, TEST_DOCUMENT_HASH, block.timestamp);

        vm.prank(user);
        uint256 requestId = rollup.requestTokenization(assetId, amount, TEST_DOCUMENT_HASH);

        assertEq(requestId, expectedRequestId);
    }

    function test_RequestTokenization_RevertIfZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("RWARollup: amount must be greater than zero");
        rollup.requestTokenization(1, 0, TEST_DOCUMENT_HASH);
    }

    function test_RequestTokenization_RevertIfZeroDocumentHash() public {
        vm.prank(user);
        vm.expectRevert("RWARollup: document hash required");
        rollup.requestTokenization(1, 100, bytes32(0));
    }

    function test_VerifyDocumentInclusion() public {
        // Initially should return false for any block
        assertFalse(rollup.verifyDocumentInclusion(TEST_DOCUMENT_HASH, 1));

        // After committing a block, should return true since block exists
        vm.prank(owner);
        rollup.commitBlock(keccak256("state"), keccak256("da"));

        assertTrue(rollup.verifyDocumentInclusion(TEST_DOCUMENT_HASH, 1));
    }

    function test_RegisterDocument() public {
        uint256 assetId = 1;

        vm.prank(owner);
        bytes32 returnedHash = rollup.registerDocument(
            assetId,
            TEST_DOCUMENT_HASH,
            TEST_DOCUMENT_URI,
            TEST_DOCUMENT_TYPE
        );

        assertEq(returnedHash, TEST_DOCUMENT_HASH);

        // Verify document was registered
        DocumentRegistry.DocumentRecord memory record = rollup.getLatestDocument(assetId);
        assertEq(record.assetId, assetId);
        assertEq(record.documentHash, TEST_DOCUMENT_HASH);
    }

    function test_RegisterDocument_RevertIfNotOwner() public {
        uint256 assetId = 1;

        vm.prank(user);
        vm.expectRevert();
        rollup.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);
    }

    function test_GetLatestDocument() public {
        uint256 assetId = 1;

        vm.prank(owner);
        rollup.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);

        DocumentRegistry.DocumentRecord memory record = rollup.getLatestDocument(assetId);
        assertEq(record.assetId, assetId);
        assertEq(record.documentHash, TEST_DOCUMENT_HASH);
        assertEq(record.documentURI, TEST_DOCUMENT_URI);
        assertEq(record.documentType, TEST_DOCUMENT_TYPE);
    }

    function test_GetDocumentRecord() public {
        // This should return the latest document record
        vm.prank(owner);
        rollup.registerDocument(1, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);

        DocumentRegistry.DocumentRecord memory record = rollup.getLatestDocument(1);

        assertEq(record.documentHash, TEST_DOCUMENT_HASH);
        assertEq(record.documentURI, TEST_DOCUMENT_URI);
        assertEq(record.documentType, TEST_DOCUMENT_TYPE);
        assertEq(record.submitter, address(rollup)); // Submitter is the rollup contract
        assertGt(record.registeredAt, 0);
    }
}