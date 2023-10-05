# Copyright 2023 Arm Limited and/or its affiliates
# <open-source-office@arm.com>
# SPDX-License-Identifier: MIT

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/Tools/cmake)
include(ConvertElfToBin)
include(ExternalProject)

ExternalProject_Get_Property(tf-m-build BINARY_DIR)

function(iot_reference_arm_corstone3xx_tf_m_sign_image target signed_target_name version pad)
    if(${pad})
        set(pad_option "--pad")
    else()
        set(pad_option "")
    endif()
    target_elf_to_bin(${target} ${target}_unsigned)
    add_custom_command(
        TARGET
            ${target}
        POST_BUILD
        DEPENDS
            $<TARGET_FILE_DIR:${target}>/${target}.bin
        COMMAND
            # Sign the non-secure (application) image for TF-M bootloader (BL2)
            python3 ${BINARY_DIR}/install/image_signing/scripts/wrapper/wrapper.py
                -v ${version}
                --layout ${BINARY_DIR}/install/image_signing/layout_files/signing_layout_ns.o
                -k ${BINARY_DIR}/install/image_signing/keys/root-RSA-2048_1.pem
                --public-key-format full
                --align 1 --pad-header ${pad_option} -H 0x400 -s auto
                --measured-boot-record
                --confirm
                $<TARGET_FILE_DIR:${target}>/${target}_unsigned.bin
                $<TARGET_FILE_DIR:${target}>/${signed_target_name}.bin
        COMMAND
        # Copy the bootloader image
        ${CMAKE_COMMAND} -E copy
            ${BINARY_DIR}/install/outputs/bl2.axf
            ${CMAKE_BINARY_DIR}/bootloader/bl2.axf
        COMMAND
        # Copy the signed TF-M image
        ${CMAKE_COMMAND} -E copy
            ${BINARY_DIR}/install/outputs/tfm_s_signed.bin
            ${CMAKE_BINARY_DIR}/secure_partition/tfm_s_signed.bin
        COMMAND
        # Copy the encrypted provisioning bundle image
        ${CMAKE_COMMAND} -E copy
            ${BINARY_DIR}/install/outputs/encrypted_provisioning_bundle.bin
            ${CMAKE_BINARY_DIR}/secure_partition/encrypted_provisioning_bundle.bin

        COMMAND
            ${CMAKE_COMMAND} -E echo "-- signed: $<TARGET_FILE_DIR:${target}>/${signed_target_name}.bin"
        VERBATIM
    )
endfunction()
