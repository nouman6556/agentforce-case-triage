import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getTriage from '@salesforce/apex/CaseTriageController.getTriage';
import applyTriage from '@salesforce/apex/CaseTriageController.applyTriage';

export default class CaseTriageCard extends LightningElement {
    @api recordId;
    triage;
    error;
    isApplying = false;

    @wire(getTriage, { caseId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.triage = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unable to triage case';
        }
    }

    get priorityClass() {
        const p = this.triage && this.triage.priority;
        if (p === 'Critical') return 'slds-theme_error';
        if (p === 'High') return 'slds-theme_warning';
        return 'slds-theme_success';
    }

    async handleApply() {
        this.isApplying = true;
        try {
            await applyTriage({ caseId: this.recordId });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Case triaged',
                message: `Priority set and routed to ${this.triage.targetQueue} (if the queue exists).`,
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Triage failed',
                message: e.body ? e.body.message : e.message,
                variant: 'error'
            }));
        } finally {
            this.isApplying = false;
        }
    }
}
