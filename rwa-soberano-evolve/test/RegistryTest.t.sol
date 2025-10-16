// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DocumentRegistry} from "../src/DocumentRegistry.sol";
import {RWASovereignRollup} from "../src/RWASovereignRollup.sol";

//import {AssetRegistry} from "../src/AssetRegistry.sol";

contract RegistryTest is Test {
    DocumentRegistry public registry;
    RWASovereignRollup public rollup;

    address public deployer = address(0xdead);
    address public aggregator = address(0xbeef);
    address public user = address(0xcafe);

    // Hash de ejemplo de un documento legal (simulando SHA256)
    bytes32 public constant TEST_HASH_1 = sha256(" Legal Document Version 1.0");
    bytes32 public constant TEST_HASH_2 =
        sha256(" Legal Document Version 2.0 - Upgrade");

    function setUp() public {
        vm.label(deployer, "Deployer_Owner");
        vm.label(aggregator, "Aggregator");
        vm.label(user, "User");

        // Desplegar el registro
        vm.prank(deployer);
        rollup = new RWASovereignRollup();

        registry = rollup.documentRegistry();
    }

    // --- Pruebas de DocumentRegistry Funcionamiento Central ---

    function testDocumentRegistration() public {
        // 1. El dueño registra el primer hash
        vm.prank(deployer);
        bytes32 daTxHash = registry.registerDocument(TEST_HASH_1);

        DocumentRegistry.DocumentRecord memory record = registry
            .getDocumentRecord(registry.RWA_ID());
        assertEq(record.documentHash, TEST_HASH_1, "Documento hash mismatch");
        assertEq(
            record.daTransactionHash,
            daTxHash,
            "DA transaction hash mismatch"
        );
        assertEq(
            record.registeredBy,
            deployer,
            "RegisteredBy address mismatch"
        );
        assertTrue(record.timestamp > 0, "Timestamp should be set");
    }

    function testDocumentVerification() public {
        // Precondicion: Hash registrado
        vm.prank(deployer);
        registry.registerDocument(TEST_HASH_1);

        // 2. Verificar que el hash registrado es correcto

        bool isValid = registry.verifyDocument(TEST_HASH_1, registry.RWA_ID());
        assertTrue(isValid, "Document should be verified");

        bool isInvalid = registry.verifyDocument(
            keccak256("wrong"),
            registry.RWA_ID()
        );
        assertTrue(!isInvalid, "Wrong document should not be verified");
    }

    function testDocumentUpdate() public {
        // Precondicion: Hash 1 registrado
        vm.startPrank(deployer);
        registry.registerDocument(TEST_HASH_1);
        registry.updateDocument(TEST_HASH_2);
        vm.stopPrank();

        DocumentRegistry.DocumentRecord memory record = registry
            .getDocumentRecord(registry.RWA_ID());
        assertEq(
            record.documentHash,
            TEST_HASH_2,
            "Document should be updated"
        );
    }

    // --- Pruebas de RWASovereignRollup ---

    function testRollupBlockCommit() public {
        bytes32 stateRoot = keccak256("stateRoot_v1");
        bytes32 daHash = keccak256("daHash_v1");

        vm.prank(deployer);
        rollup.commitBlock(stateRoot, daHash);

        (
            bytes32 storedStateRoot,
            bytes32 storedDAHash,
            uint256 timestamp,
            address blockAggregator
        ) = rollup.blocks(1);
        assertEq(storedStateRoot, stateRoot, "State root mismatch");
        assertEq(storedDAHash, daHash, "DA hash mismatch");
    assertEq(blockAggregator, deployer, "Aggregator address mismatch");
        assertTrue(timestamp > 0, "Timestamp should be set");
    }

    function testTokenizationRequest() public {
        vm.prank(user);
        uint256 requestId = rollup.requestTokenization(1000e18, TEST_HASH_1);

        assertTrue(requestId > 0, "Request ID should be generated");

        // Verificar que los eventos fueron emitidos
        vm.expectEmit(true, true, true, true);
        emit RWASovereignRollup.TokenizationRequested(
            user,
            1000e18,
            TEST_HASH_1,
            block.timestamp
        );
    }

    function testDocumentInclusionVerification() public {
        bytes32 stateRoot = keccak256("state_root");
        bytes32 daHash = keccak256("da_hash");

        vm.prank(deployer);
        rollup.commitBlock(stateRoot, daHash);

        bool isIncluded = rollup.verifyDocumentInclusion(TEST_HASH_1, 1);
        assertTrue(isIncluded, "Document should be considered included");
    }

    // --- Pruebas de Seguridad ---

    function testOnlyOwnerCanRegisterDocument() public {
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.registerDocument(TEST_HASH_1);
    }

    function testCannotRegisterZeroHash() public {
        vm.prank(deployer);
        vm.expectRevert("DocumentRegistry: hash cannot be zero");
        registry.registerDocument(bytes32(0));
    }

    function testCannotUpdateNonExistentDocument() public {
        vm.prank(deployer);
        vm.expectRevert("DocumentRegistry: no document to update");
        registry.updateDocument(TEST_HASH_1);
    }

    // --- Pruebas de Integración ---

    function testFullIntegration() public {
        // 1. Registrar documento
        vm.prank(deployer);
        bytes32 daTxHash = registry.registerDocument(TEST_HASH_1);

        // 2. Solicitar tokenización
        vm.prank(user);
        uint256 requestId = rollup.requestTokenization(500e18, TEST_HASH_1);

        // 3. Commit bloque al rollup
        vm.prank(deployer);
        rollup.commitBlock(
            keccak256(abi.encodePacked("state_root", requestId)),
            keccak256(abi.encodePacked("da_batch", daTxHash))
        );

        // 4. Verificar integridad
        DocumentRegistry.DocumentRecord memory docRecord = rollup
            .getDocumentRecord();
        assertEq(
            docRecord.documentHash,
            TEST_HASH_1,
            "Document integrity check"
        );

        bool docIncluded = rollup.verifyDocumentInclusion(TEST_HASH_1, 1);
        assertTrue(docIncluded, "Document should be included in rollup");
    }

    function testGasEfficiency() public {
        vm.prank(deployer);
        uint256 gasBefore = gasleft();
        registry.registerDocument(TEST_HASH_1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for document registration:", gasUsed);
        assertTrue(
            gasUsed < 100000,
            "Document registration should be gas efficient"
        );
    }
}
