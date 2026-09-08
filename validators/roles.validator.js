import Joi from 'joi';

class RolesValidator {
  createRole() {
    return Joi.object({
      role_name: Joi.string().max(100).trim().required(),
      description: Joi.string().allow(null, ''),
    });
  }

  getRoles() {
    return Joi.object({});
  }

  updateRole() {
    return Joi.object({
      role_id: Joi.number().required(),
      role_name: Joi.string().max(100).trim().required(),
      description: Joi.string().allow(null, ''),
    });
  }

  deleteRole() {
    return Joi.object({
      role_id: Joi.number().required(),
    });
  }
}

export default new RolesValidator();