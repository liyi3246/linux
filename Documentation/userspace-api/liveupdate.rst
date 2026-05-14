.. SPDX-License-Identifier: GPL-2.0

================
Live Update uAPI
================
:Author: Pasha Tatashin <pasha.tatashin@soleen.com>

ioctl interface
===============
.. kernel-doc:: kernel/liveupdate/luo_core.c
   :doc: LUO ioctl Interface

ioctl uAPI
===========
.. kernel-doc:: include/uapi/linux/liveupdate.h

See Also
========

- :doc:`Live Update Orchestrator </core-api/liveupdate>`


Troubleshooting kexec hangs with liveupdate enabled
===================================================

When the system hangs during kexec even before any memory/file preservation
operation is performed, use the following workflow to narrow down the failure:

1. Reproduction matrix:

   - ``liveupdate=off`` × ``kho=off``
   - ``liveupdate=off`` × ``kho=on``
   - ``liveupdate=on`` × ``kho=off``
   - ``liveupdate=on`` × ``kho=on``

   Under ``liveupdate=on,kho=on``, run both:

   - do not access ``/dev/liveupdate`` at all
   - open/close ``/dev/liveupdate`` only (no session creation, no preserve)

2. Make post-``kexec: Bye!`` progress observable in the next kernel:

   - pass early/verbose logging args to the target kernel, such as
     ``loglevel=8 initcall_debug`` and platform-specific early console args
   - enable pstore/ramoops so early boot logs survive and can be collected
     after reboot

3. Capture KHO/LUO metadata before executing kexec:

   - ``/sys/kernel/debug/kho/out/fdt``
   - ``/sys/kernel/debug/kho/out/sub_fdts/*``
   - ``/sys/kernel/debug/kho/out/scratch_len``
   - ``/sys/kernel/debug/kho/out/scratch_phys``

   The helper script
   ``tools/testing/selftests/liveupdate/luo_kexec_triage.sh``
   automates this collection and supports the "open-only /dev/liveupdate"
   scenario through ``ACCESS_LIVEUPDATE=open``.

4. Compare logs around kexec transition:

   Focus on log differences from ``kernel_restart_prepare`` to
   ``machine_kexec`` between ``liveupdate=off`` and ``liveupdate=on``.
   If storage I/O errors (for example SCSI writeback failures) are present,
   validate independently whether they reproduce without liveupdate.

5. Escalation gate:

   If logs consistently show failure in LUO reboot serialization,
   inspect messages from ``liveupdate_reboot()``,
   ``luo_session_serialize()``, and ``luo_flb_serialize()`` to determine
   whether failure happens before session freeze, during session freeze, or
   after FLB snapshot generation.
