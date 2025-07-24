import QtQuick 2.15
import QtQuick.Controls 2.15

GroupBox {
    // We can't do the direct bind with the template element in the component body
    Binding {
        target: label ? label : undefined
        property: "horizontalAlignment"
        when: visible
        value: Text.AlignHCenter
    }
}
