// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import "../src/DocumentRegistry.sol";

contract DocumentRegistryTest is Test {
    DocumentRegistry public registry;
    address public owner;
    address public registrar;
    address public user;

    bytes32 constant TEST_DOCUMENT_HASH = keccak256("test document");
    string constant TEST_DOCUMENT_URI = "ipfs://QmTest";
    string constant TEST_DOCUMENT_TYPE = "Legal Document";

    event DocumentRegistered(
        uint256 indexed assetId,
        bytes32 indexed documentHash,
        string documentURI,
        string documentType,
        address indexed submitter
    );

    function setUp() public {
        owner = address(this);
        registrar = makeAddr("registrar");
        user = makeAddr("user");

        registry = new DocumentRegistry();

        // Grant registrar role to registrar
        registry.grantRegistrar(registrar);
    }

    function test_Constructor() public {
        assertEq(registry.owner(), owner);
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(registry.hasRole(registry.REGISTRAR_ROLE(), owner));
    }

    function test_RegisterDocument_Success() public {
        uint256 assetId = 1;

        vm.prank(registrar);
        vm.expectEmit(true, true, true, true);
        emit DocumentRegistered(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE, registrar);

        bytes32 returnedHash = registry.registerDocument(
            assetId,
            TEST_DOCUMENT_HASH,
            TEST_DOCUMENT_URI,
            TEST_DOCUMENT_TYPE
        );

        assertEq(returnedHash, TEST_DOCUMENT_HASH);

        // Verify document is registered
        DocumentRegistry.DocumentRecord memory record = registry.getLatestDocument(assetId);
        assertEq(record.assetId, assetId);
        assertEq(record.documentHash, TEST_DOCUMENT_HASH);
        assertEq(record.documentURI, TEST_DOCUMENT_URI);
        assertEq(record.documentType, TEST_DOCUMENT_TYPE);
        assertEq(record.submitter, registrar);
        assertGt(record.registeredAt, 0);

        // Verify in history
        DocumentRegistry.DocumentRecord[] memory history = registry.getDocumentHistory(assetId);
        assertEq(history.length, 1);
        assertEq(history[0].documentHash, TEST_DOCUMENT_HASH);
    }

    function test_RegisterDocument_RevertIfNotRegistrar() public {
        uint256 assetId = 1;

        vm.prank(user);
        vm.expectRevert();
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);
    }

    function test_RegisterDocument_RevertIfZeroHash() public {
        uint256 assetId = 1;

        vm.prank(registrar);
        vm.expectRevert("Registry: invalid document hash");
        registry.registerDocument(assetId, bytes32(0), TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);
    }

    function test_RegisterDocument_RevertIfEmptyURI() public {
        uint256 assetId = 1;

        vm.prank(registrar);
        vm.expectRevert("Registry: document URI required");
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, "", TEST_DOCUMENT_TYPE);
    }

    function test_RegisterDocument_RevertIfEmptyType() public {
        uint256 assetId = 1;

        vm.prank(registrar);
        vm.expectRevert("Registry: document type required");
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, "");
    }

    function test_RegisterDocument_RevertIfAlreadyRegistered() public {
        uint256 assetId = 1;

        vm.startPrank(registrar);
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);

        vm.expectRevert("Registry: document already registered");
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, "different_uri", "different_type");
        vm.stopPrank();
    }

    function test_GetLatestDocument_RevertIfNoDocument() public {
        uint256 assetId = 999;

        vm.expectRevert("Registry: no document for asset");
        registry.getLatestDocument(assetId);
    }

    function test_GetDocumentHistory_Empty() public {
        uint256 assetId = 1;

        DocumentRegistry.DocumentRecord[] memory history = registry.getDocumentHistory(assetId);
        assertEq(history.length, 0);
    }

    function test_GetDocumentHistory_MultipleDocuments() public {
        uint256 assetId = 1;
        bytes32 hash2 = keccak256("second document");
        string memory uri2 = "ipfs://QmSecond";
        string memory type2 = "Contract";

        vm.startPrank(registrar);
        registry.registerDocument(assetId, TEST_DOCUMENT_HASH, TEST_DOCUMENT_URI, TEST_DOCUMENT_TYPE);
        registry.registerDocument(assetId, hash2, uri2, type2);
        vm.stopPrank();

        DocumentRegistry.DocumentRecord[] memory history = registry.getDocumentHistory(assetId);
        assertEq(history.length, 2);

        // Check first document
        assertEq(history[0].documentHash, TEST_DOCUMENT_HASH);
        assertEq(history[0].documentURI, TEST_DOCUMENT_URI);

        // Check second document (latest)
        assertEq(history[1].documentHash, hash2);
        assertEq(history[1].documentURI, uri2);

        // Latest should be the second one
        DocumentRegistry.DocumentRecord memory latest = registry.getLatestDocument(assetId);
        assertEq(latest.documentHash, hash2);
    }

    function test_GrantRegistrar() public {
        address newRegistrar = makeAddr("newRegistrar");

        vm.prank(owner);
        registry.grantRegistrar(newRegistrar);

        assertTrue(registry.hasRole(registry.REGISTRAR_ROLE(), newRegistrar));
    }

    function test_GrantRegistrar_RevertIfNotOwner() public {
        address newRegistrar = makeAddr("newRegistrar");

        vm.prank(user);
        vm.expectRevert();
        registry.grantRegistrar(newRegistrar);
    }

    function test_GrantRegistrar_RevertIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Registry: zero address");
        registry.grantRegistrar(address(0));
    }

    function test_RevokeRegistrar() public {
        vm.prank(owner);
        registry.revokeRegistrar(registrar);

        assertFalse(registry.hasRole(registry.REGISTRAR_ROLE(), registrar));
    }

    function test_RevokeRegistrar_RevertIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        registry.revokeRegistrar(registrar);
    }

    function test_RevokeRegistrar_RevertIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Registry: zero address");
        registry.revokeRegistrar(address(0));
    }

    function test_SupportsInterface() public {
        // Test ERC165 interfaces
        assertTrue(registry.supportsInterface(type(IAccessControl).interfaceId));
    }
}