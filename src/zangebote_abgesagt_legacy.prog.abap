*&---------------------------------------------------------------------*
*& Report  ZANGEBOTE_ABGESAGT_LEGACY
*& Abgesagte Angebote (Grund "zu teuer") kumulieren.
*& Enthaelt viele Eigenschaften von Legacy Code
*& und soll deshalb ersetzt werden
*&---------------------------------------------------------------------*
*& MIT License
*& Copyright (c) 2019 Johannes Gerbershagen
*
*& THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*& IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*& FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*& AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*& LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*& OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*& SOFTWARE.

REPORT ZANGEBOTE_ABGESAGT_LEGACY.

TABLES: vbkd, vbak, vbap.
SELECT-OPTIONS: bstdk FOR vbkd-bstdk,
  kunnr FOR vbak-kunnr,
  matnr FOR vbap-matnr.
PARAMETERS: layout TYPE slis_vari.

START-OF-SELECTION.
  DATA: lt_vbkd TYPE STANDARD TABLE OF vbkd,
        ls_vbak TYPE vbak,
        ls_vbap TYPE vbap,
        ls_out TYPE zangebot_summe_kunde_artikel,
        lt_outtab TYPE STANDARD TABLE OF zangebot_summe_kunde_artikel,
        h_netpr_von TYPE netpr,
        h_netpr_bis TYPE netpr,
        h_netpr TYPE netpr,
        h_tabix TYPE i,
        append TYPE i,
        ls_variant TYPE disvariant.

  FIELD-SYMBOLS: <fs_vbkd> TYPE vbkd.

  SELECT * FROM vbkd INTO TABLE lt_vbkd
    WHERE bstdk IN bstdk.

  LOOP AT lt_vbkd ASSIGNING <fs_vbkd>.
    SELECT * FROM vbak INTO ls_vbak
      WHERE vbeln = <fs_vbkd>-vbeln.

      CHECK ls_vbak-kunnr IN kunnr AND ls_vbak-vbtyp = 'B'.

      SELECT * FROM vbap INTO ls_vbap
        WHERE vbeln = ls_vbak-vbeln AND matnr IN matnr
        AND netpr > 0.

        CLEAR ls_out.
        READ TABLE lt_outtab INTO ls_out WITH KEY
          kunnr = ls_vbak-kunnr artikel = ls_vbap-matnr
          monat = <fs_vbkd>-bstdk+0(6) waerk = ls_vbap-waerk.
        append = sy-subrc.
        h_tabix = sy-tabix.
        IF append <> 0.
          ls_out-kunnr = ls_vbak-kunnr.
          ls_out-monat = <fs_vbkd>-bstdk+0(6).
          ls_out-artikel = ls_vbap-matnr.
          ls_out-waerk = ls_vbap-waerk.
        ENDIF.
        ADD 1 TO ls_out-anzahl_gesamt.

        IF ls_vbap-abgru = '02'.

          ADD 1 TO ls_out-anzahl_abgesagt.
          h_netpr_von = 0. h_netpr_bis = 0.
          IF ls_out-netto_preis_von > 0.
            h_netpr_von = ls_out-netto_preis_von / ls_out-kpein_von.
          ENDIF.
          IF ls_out-netto_preis_bis > 0.
            h_netpr_bis = ls_out-netto_preis_bis / ls_out-kpein_bis.
          ENDIF.
          h_netpr = ls_vbap-netpr / ls_vbap-kpein.
          " Umrechnung pro Stueck
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
          " Vergleich
          IF h_netpr < h_netpr_von OR h_netpr_von = 0.
            ls_out-netto_preis_von = ls_vbap-netpr.
            ls_out-kpein_von = ls_vbap-kpein.
          ENDIF.
          IF h_netpr > h_netpr_bis.
            ls_out-netto_preis_bis = ls_vbap-netpr.
            ls_out-kpein_bis = ls_vbap-kpein.
          ENDIF.

        ENDIF.
        IF append <> 0.
          APPEND ls_out TO lt_outtab.
        ELSE.
          MODIFY lt_outtab FROM ls_out INDEX h_tabix.
        ENDIF.

      ENDSELECT.

    ENDSELECT.
  ENDLOOP.

  LOOP AT lt_outtab INTO ls_out.
    h_tabix = sy-tabix.

    ls_out-ver_abs = ls_out-anzahl_abgesagt / ls_out-anzahl_gesamt.

    SELECT SINGLE name1 FROM kna1 INTO ls_out-name_kunde
      WHERE kunnr = ls_out-kunnr.
    SELECT SINGLE maktx FROM makt INTO ls_out-bez_artikel
      WHERE spras = sy-langu AND matnr = ls_out-artikel.
    MODIFY lt_outtab FROM ls_out INDEX h_tabix.

  ENDLOOP.

  ls_variant-report = sy-repid.
  ls_variant-variant = layout.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_save = 'A'
      is_variant = ls_variant
      i_structure_name = 'ZANGEBOT_SUMME_KUNDE_ARTIKEL'
    TABLES
      t_outtab = lt_outtab.
