package org.techadvision.pulse;

import org.techadvision.pulse.KoggerUsbId;

import com.hoho.android.usbserial.driver.ProbeTable;
import com.hoho.android.usbserial.driver.UsbSerialProber;

public class KoggerProber
{
    public static UsbSerialProber getKoggerProber() {
        return new UsbSerialProber(getKoggerProbeTable());
    }

    public static ProbeTable getKoggerProbeTable() {
        final ProbeTable probeTable = new ProbeTable();

        return probeTable;
    }
}
