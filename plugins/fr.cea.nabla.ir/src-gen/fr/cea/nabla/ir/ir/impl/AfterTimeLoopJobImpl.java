/**
 */
package fr.cea.nabla.ir.ir.impl;

import fr.cea.nabla.ir.ir.AfterTimeLoopJob;
import fr.cea.nabla.ir.ir.IrPackage;
import fr.cea.nabla.ir.ir.TimeLoopJob;
import org.eclipse.emf.common.notify.Notification;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.InternalEObject;
import org.eclipse.emf.ecore.impl.ENotificationImpl;

/**
 * <!-- begin-user-doc -->
 * An implementation of the model object '<em><b>After Time Loop Job</b></em>'.
 * <!-- end-user-doc -->
 * <p>
 * The following features are implemented:
 * </p>
 * <ul>
 *   <li>{@link fr.cea.nabla.ir.ir.impl.AfterTimeLoopJobImpl#getAssociatedTimeLoop <em>Associated Time Loop</em>}</li>
 * </ul>
 *
 * @generated
 */
public class AfterTimeLoopJobImpl extends TimeLoopCopyJobImpl implements AfterTimeLoopJob {
	/**
	 * The cached value of the '{@link #getAssociatedTimeLoop() <em>Associated Time Loop</em>}' reference.
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @see #getAssociatedTimeLoop()
	 * @generated
	 * @ordered
	 */
	protected TimeLoopJob associatedTimeLoop;
	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	protected AfterTimeLoopJobImpl() {
		super();
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	protected EClass eStaticClass() {
		return IrPackage.Literals.AFTER_TIME_LOOP_JOB;
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public TimeLoopJob getAssociatedTimeLoop() {
		if (associatedTimeLoop != null && associatedTimeLoop.eIsProxy()) {
			InternalEObject oldAssociatedTimeLoop = (InternalEObject)associatedTimeLoop;
			associatedTimeLoop = (TimeLoopJob)eResolveProxy(oldAssociatedTimeLoop);
			if (associatedTimeLoop != oldAssociatedTimeLoop) {
				if (eNotificationRequired())
					eNotify(new ENotificationImpl(this, Notification.RESOLVE, IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP, oldAssociatedTimeLoop, associatedTimeLoop));
			}
		}
		return associatedTimeLoop;
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	public TimeLoopJob basicGetAssociatedTimeLoop() {
		return associatedTimeLoop;
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public void setAssociatedTimeLoop(TimeLoopJob newAssociatedTimeLoop) {
		TimeLoopJob oldAssociatedTimeLoop = associatedTimeLoop;
		associatedTimeLoop = newAssociatedTimeLoop;
		if (eNotificationRequired())
			eNotify(new ENotificationImpl(this, Notification.SET, IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP, oldAssociatedTimeLoop, associatedTimeLoop));
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public Object eGet(int featureID, boolean resolve, boolean coreType) {
		switch (featureID) {
			case IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP:
				if (resolve) return getAssociatedTimeLoop();
				return basicGetAssociatedTimeLoop();
		}
		return super.eGet(featureID, resolve, coreType);
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public void eSet(int featureID, Object newValue) {
		switch (featureID) {
			case IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP:
				setAssociatedTimeLoop((TimeLoopJob)newValue);
				return;
		}
		super.eSet(featureID, newValue);
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public void eUnset(int featureID) {
		switch (featureID) {
			case IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP:
				setAssociatedTimeLoop((TimeLoopJob)null);
				return;
		}
		super.eUnset(featureID);
	}

	/**
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @generated
	 */
	@Override
	public boolean eIsSet(int featureID) {
		switch (featureID) {
			case IrPackage.AFTER_TIME_LOOP_JOB__ASSOCIATED_TIME_LOOP:
				return associatedTimeLoop != null;
		}
		return super.eIsSet(featureID);
	}

} //AfterTimeLoopJobImpl
