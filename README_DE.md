# Sinn #
Dieses Repository soll ein mögliches Verfahren aufzeigen, um Legacy Code durch eine Clean Code
Implementierung zu ersetzen. Das Verhalten der Legacy Code Implementierung ist schwierig 
zu analysieren. Daher wird der Legacy Code dahin gehend modifiziert, dass dieser mit der Clean-Code Implementierung verglichen werden kann.
Anwendung findet dieses Verfahren daher nur in Algorithmen, die Daten auschließlich anzeigen und keine Modifikationen an persistenten Daten vornehmen.

## Die Auswertung ##
Das Repository enthält 2 Programme. Einmal das Programm ```zangebote_abgesagt_legacy```, das eine Auswertung über abgesagte Angebote analog zu den Anforderungen im Repository [https://github.com/germanysources/clean_code_demo](https://github.com/germanysources/clean_code_demo) dem Benutzer im ALV-Grid darstellt. Dieses Programm enthält viele Merkmale, die für Legacy Code typisch sind. Unter anderem wurde eine Einheitenumrechnung mit einer case-when Bedingung gelöst.
Diese Enheitenumrechnung soll durch allgemeingültige Einheitenumrechnung, die SAP mit dem Funktionsbaustein ```MATERIAL_UNIT_CONVERSION``` bereitstellt, ersetzt werden.

### Bisherige Einheitenumrechnung ###
```ABAP
CASE ls_vbap-kmein.
  WHEN 'PAL'.
    h_netpr = h_netpr / 300. "Palette enthaelt 300 Stueck
    ls_out-kmein = 'ST'.
  WHEN 'TS'.
    h_netpr = h_netpr / 1000.
    ls_out-kmein = 'ST'.
  WHEN OTHERS.
    ls_out-kmein = ls_vbap-kmein.
ENDCASE.
```

## Schritte um den Legacy Code zu ersetzen ##

### Idee ###
Im Repository [https://github.com/germanysources/clean_code_demo](https://github.com/germanysources/clean_code_demo) liegt bereits die Clean Code Implementierung.
Wir wollen das Verhalten des Legacy Codes mit dem Verhalten der Clean Code Implementierung vergleichen, um Differenzen zwischen den beiden Algorithmen zu finden. So können wir sichergehen, dass die Clean Code Implementierung kein bestehendes Verhalten der Legacy Code Implementierung ändert.
Unit-Tests sind im Legacy Code nur schwer möglich. Da die beiden Implementierungen nur interne Tabellen für die Anzeige im ALV-Grid bereitstellen, können diese Daten verglichen werden.

### 1.Schritt ###
Das Programm ```zangebote_abgesagt_legacy``` wird in das Programm ```zangebote_abgesagt_legacy_rep``` kopiert. 

### 2.Schritt ###
Die Anzeige der Daten im ALV-Grid wird deaktiviert.
```ABAP
" Anzeige im ALV-Grid deaktivieren
"  ls_variant-report = sy-repid.
"  ls_variant-variant = layout.
"  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
"    EXPORTING
"      i_save = 'A'
"      is_variant = ls_variant
"      i_structure_name = 'ZANGEBOT_SUMME_KUNDE_ARTIKEL'
"    TABLES
"      t_outtab = lt_outtab.
```

### 3.Schritt ###
Die Subroutine ```vergleich_algorithmen```, die Struktur ```_mismatch``` und der Tabellentyp ```_mismatch``` wird dem Programm ```zangebote_abgesagt_legacy_rep``` hinzugefügt. Die Subroutine ```vergleich_algorithmen``` vergleicht die Legacy Code Implementierung mit der Clean Code Implementierung.
```ABAP
TYPES: BEGIN OF __mismatch,
  alt TYPE zangebot_summe_kunde_artikel,
  neu TYPE zangebot_summe_kunde_artikel,
END OF __mismatch,
_mismatch TYPE STANDARD TABLE OF __mismatch.
```

```ABAP
*! alt_summe mit der ermittelten Summe in der Klasse zangebote_abgesagt vergleichen
*! @parameter mismatch | Datensaetze, die nicht uebereinstimmen
FORM vergleich_algorithmen USING alt_summe TYPE zangebote_abgesagt=>out_summe_kunde_artikel
  CHANGING mismatch TYPE _mismatch
  RAISING zcx_angebot_abgesagt.

  DATA: neu_object TYPE REF TO zangebote_abgesagt,
        neu_summe TYPE zangebote_abgesagt=>out_summe_kunde_artikel.
  FIELD-SYMBOLS: <alt> TYPE zangebot_summe_kunde_artikel,
                 <neu> LIKE <alt>,
                 <mismatch> TYPE __mismatch.

  CLEAR: mismatch.

  " neuer Algorithmus liegt in Klasse zangebote_abgesagt
  CREATE OBJECT neu_object
    EXPORTING
      bestelldaten = bstdk[]
      kunden = kunnr[]
      artikel = matnr[].

  neu_object->get_angebote( IMPORTING summe_kunde_artikel = neu_summe ).

  " Vergleich
  LOOP AT alt_summe ASSIGNING <alt>.
    " READ TABLE Anweisung vergleicht nur die Felder des Primaerschluessels (zeichenartig).
    " Die numerischen Felder muessen nochmals extra vergliechen werden.
    READ TABLE neu_summe ASSIGNING <neu> FROM <alt>.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO mismatch ASSIGNING <mismatch>.
      <mismatch>-alt = <alt>.
    ELSEIF <neu> <> <alt>.
      APPEND INITIAL LINE TO mismatch ASSIGNING <mismatch>.
      <mismatch>-alt = <alt>.
      <mismatch>-neu = <neu>.
    ENDIF.

  ENDLOOP.

  LOOP AT neu_summe ASSIGNING <neu>.
    " READ TABLE Anweisung vergleicht nur die Felder des Primaerschluessels (zeichenartig).
    " Die numerischen Felder muessen nochmals extra vergliechen werden.
    READ TABLE alt_summe ASSIGNING <alt> FROM <neu>.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO mismatch ASSIGNING <mismatch>.
      <mismatch>-neu = <neu>.
    ENDIF.
  ENDLOOP.

ENDFORM.
```

### 4.Schritt ###
Im ```start-of-selection```Ereignis wird die Subroutine ```vergleich_algorithmen``` gerufen und die Ergebnisse werden in der Konsole ausgegeben.
```ABAP
" Anzeige im ALV-Grid deaktivieren
"  ls_variant-report = sy-repid.
"  ls_variant-variant = layout.
"  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
"    EXPORTING
"      i_save = 'A'
"      is_variant = ls_variant
"      i_structure_name = 'ZANGEBOT_SUMME_KUNDE_ARTIKEL'
"    TABLES
"      t_outtab = lt_outtab.

" und durch Vergleich ersetzen
PERFORM vergleich_algorithmen USING lt_outtab
  CHANGING mismatch.

" Ausgabe Vergleich
WRITE: 'Datensaetze nicht im neuen Algorithmus vorhanden'. NEW-LINE.
LOOP AT mismatch ASSIGNING <mismatch>
  WHERE neu IS INITIAL.

  WRITE: <mismatch>-alt-kunnr, <mismatch>-alt-name_kunde,
    <mismatch>-alt-artikel, <mismatch>-alt-bez_artikel, <mismatch>-alt-monat. NEW-LINE.

ENDLOOP.

WRITE: 'Datensaetze nicht im bisherigen Algorithmus vorhanden'. NEW-LINE.
LOOP AT mismatch ASSIGNING <mismatch>
  WHERE alt IS INITIAL.

  WRITE: <mismatch>-neu-kunnr, <mismatch>-neu-name_kunde,
    <mismatch>-neu-artikel, <mismatch>-neu-bez_artikel, <mismatch>-neu-monat. NEW-LINE.

ENDLOOP.

WRITE: 'numerische Werte inkorrekt'. NEW-LINE.
LOOP AT mismatch ASSIGNING <mismatch>
  WHERE alt IS NOT INITIAL AND neu IS NOT INITIAL.

  WRITE: <mismatch>-alt-kunnr, <mismatch>-alt-name_kunde,
    <mismatch>-alt-artikel, <mismatch>-alt-bez_artikel, <mismatch>-alt-monat. NEW-LINE.
  WRITE: 'Anzahl abgesagt', 'Anzahl gesamt', 'Nettopreis von', 'Nettopreis bis', 'Preiseinheit von', 'Preiseinheit bis'. NEW-LINE.
  WRITE: 'bisheriger Algorithmus'. NEW-LINE.
  WRITE: <mismatch>-alt-anzahl_abgesagt, <mismatch>-alt-anzahl_gesamt, <mismatch>-alt-netto_preis_von, <mismatch>-alt-netto_preis_bis,
    <mismatch>-alt-netto_preis_bis, <mismatch>-alt-kpein_von, <mismatch>-alt-kpein_bis, <mismatch>-alt-kmein. NEW-LINE.
  WRITE: 'neuer Algorithmus'. NEW-LINE.
  WRITE: <mismatch>-neu-anzahl_abgesagt, <mismatch>-neu-anzahl_gesamt, <mismatch>-neu-netto_preis_von, <mismatch>-neu-netto_preis_bis,
    <mismatch>-neu-netto_preis_bis, <mismatch>-neu-kpein_von, <mismatch>-neu-kpein_bis, <mismatch>-neu-kmein. NEW-LINE.

ENDLOOP.
```

### 5.Schritt ###
Der Vergleichsreport ist jetzt fertig. Wir können diesen in das Produktivsystem transportieren, ohne dass der bisherige Report ```zangebote_abgesagt_legacy``` beeinträchtigt wird.
Jetzt können wir beide Algorithmen mit den Produktivdaten vergleichen.
Treten keine unerwarteten Differenzen mehr auf, kann die Legacy Code Implementierung durch die Clean Code Implementierung ersetzt werden.

